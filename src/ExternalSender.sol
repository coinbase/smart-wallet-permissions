// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {_packValidationData} from "account-abstraction/core/Helpers.sol";
import {IAccount} from "account-abstraction/interfaces/IAccount.sol";
import {Ownable, Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {CoinbaseSmartWalletFactory} from "smart-wallet/CoinbaseSmartWalletFactory.sol";
import {MultiOwnable} from "smart-wallet/MultiOwnable.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

import {IPermissionContract} from "./interfaces/IPermissionContract.sol";
import {BytesLib} from "./utils/BytesLib.sol";
import {CallErrors} from "./utils/CallErrors.sol";
import {SignatureCheckerLib} from "./utils/SignatureCheckerLib.sol";
import {UserOperation, UserOperationLib} from "./utils/UserOperationLib.sol";

/// @title ExternalSender (will rename, just naming the pattern for now)
///
/// @notice A staked ERC-4337 account that all Session Key User Operations will flow through.
///
/// @dev Designed for Coinbase Smart Wallet (https://github.com/coinbase/smart-wallet).
/// @dev Staked accounts can submit unlimited User Operations.
/// @dev ERC-7562 [EREP-030] holds staked accounts accountable for failures in other entities (paymaster, aggregator)
///      even if they are staked (https://eips.ethereum.org/EIPS/eip-7562#entity-specific-rules). This means that we
///      have DOS risk if paymasters or aggregators are failing via triggering throttling of this sender.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract ExternalSender is IAccount, Ownable2Step, Pausable {
    /// @notice A limited permission for an external signer to use an account.
    struct Permission {
        /// @dev Smart account this permission is valid for.
        address account;
        /// @dev Timestamp this permission is valid until (unix seconds).
        uint48 expiry;
        /// @dev The entity that has limited control of `account` in this Permission.
        /// @dev Supports abi-encoded Ethereum addresses (EOA, contract) and P256 public keys (passkey, cryptokey).
        bytes signer;
        /// @dev External contract to verify specific permission logic.
        address permissionContract;
        /// @dev Permission-specific values sent to permissionContract for validation.
        bytes permissionValues;
        /// @dev Optional signature from account owner proving a permission is approved.
        bytes approval;
    }

    /// @notice Signature data for SessionKeySender user operation.
    struct PermissionedBatch {
        /// @dev Nonce.
        uint256 nonce;
        /// @dev Expiry
        uint48 expiry;
        /// @dev Permission details.
        Permission permission;
        /// @dev Calls to batch execute.
        CoinbaseSmartWallet.Call[] calls;
        /// @dev `Permission.signer` signature over batch hash.
        bytes sessionKeySignature;
        /// @dev `this.cosigner` or `this.pendingCosigner` signature of user operation hash.
        bytes cosignerSignature;
    }

    /// @notice Expected return value for EIP-1271 `isValidSignature` call.
    /// @dev bytes4(keccak256("isValidSignature(bytes32,bytes)"))
    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

    /// @notice Singleton factory for Coinbase Smart Wallets.
    CoinbaseSmartWalletFactory public immutable factory;

    /// @notice Track if cosigner is enabled.
    mapping(address cosigner => bool enabled) public isCosignerEnabled;

    /// @notice Track if permission contracts are enabled.
    mapping(address permissionContract => bool enabled) public isPermissionContractEnabled;

    /// @notice Track if paymasters are enabled.
    mapping(address paymaster => bool enabled) public isPaymasterEnabled;

    /// @notice Track if permissions are revoked by accounts.
    mapping(bytes32 permissionHash => mapping(address account => bool revoked)) internal _isPermissionRevoked;

    /// @notice Track if permissions are approved by accounts via transactions.
    mapping(bytes32 permissionHash => mapping(address account => bool approved)) internal _isPermissionApproved;

    /// @notice
    mapping(address account => mapping(uint256 nonce => bool used)) internal _usedNonces;

    /// @notice Permission is unauthorized by either revocation or lack of approval.
    error UnauthorizedPermission();

    /// @notice Invalid signature.
    error InvalidSignature();

    /// @notice Renouncing ownership attempted but not allowed.
    error CannotRenounceOwnership();

    /// @notice Permission was approved via transaction.
    ///
    /// @param account The smart contract account the permission controls.
    /// @param permissionHash The unique hash representing the permission.
    event PermissionApproved(address indexed account, bytes32 indexed permissionHash);

    /// @notice Permission was revoked prematurely by account.
    ///
    /// @param account The smart contract account the permission controlled.
    /// @param permissionHash The unique hash representing the permission.
    event PermissionRevoked(address indexed account, bytes32 indexed permissionHash);

    /// @notice Cosigner setting updated.
    ///
    /// @param cosigner Second factor verifier leveraging offchain validation.
    /// @param enabled The new setting allowing/preventing use.
    event CosignerUpdated(address indexed cosigner, bool enabled);

    /// @notice Permission contract setting updated.
    ///
    /// @param permissionContract The contract resposible for checking permission logic.
    /// @param enabled The new setting allowing/preventing use.
    event PermissionContractUpdated(address indexed permissionContract, bool enabled);

    /// @notice Paymaster setting updated.
    ///
    /// @param paymaster ERC-4337 paymaster contract.
    /// @param enabled The new setting allowing/preventing use.
    event PaymasterUpdated(address indexed paymaster, bool enabled);

    /// @notice Constructor.
    constructor(address initialOwner, address smartWalletFactory) Ownable(initialOwner) Pausable() {
        factory = CoinbaseSmartWalletFactory(smartWalletFactory);
    }

    /// @notice Reverts if the caller is not the EntryPoint.
    modifier onlyEntryPoint() virtual {
        if (msg.sender != entryPoint()) {
            revert MultiOwnable.Unauthorized();
        }

        _;
    }

    /// @notice Validate a session key user operation.
    ///
    /// @dev Delays permission revoked check to execution phase to mitigate reputation damage from revoke-frontruns.
    function validateUserOp(UserOperation calldata userOp, bytes32, /*userOpHash*/ uint256 /*missingAccountFunds*/ )
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        // check paymaster enabled, must protect against paymaster DOS
        if (!isPaymasterEnabled[address(bytes20(userOp.paymasterAndData))]) return 1; // failure

        return 0; // success
    }

    /// @notice Call `CoinbaseSmartWallet.executeBatch` with calls.
    function forwardBatch(PermissionedBatch calldata batch) public {
        bytes32 permissionHash = hashPermission(batch.permission);
        bytes32 batchHash = hashPermissionedBatch(permissionHash, batch.calls);

        if (msg.sender == entryPoint()) {
            // if sender is EntryPoint, validate session key signature
            if (!SignatureCheckerLib.isValidSignatureNow(batchHash, batch.sessionKeySignature, batch.permission.signer))
            {
                revert();
            }
        } else {
            // enfoce sender is permission signer
            if (batch.permission.signer.length != 32) revert();
            if (uint256(bytes32(batch.permission.signer)) > type(uint160).max) revert();
            if (address(bytes20(batch.permission.signer)) != msg.sender) revert();
        }

        // check signatures not expired
        if (block.timestamp > batch.expiry) revert();

        // check permission not expired
        if (block.timestamp > batch.permission.expiry) revert();

        // check nonce used and use it if not
        if (_usedNonces[batch.permission.account][batch.nonce]) revert();
        else _usedNonces[batch.permission.account][batch.nonce] = true;

        // check pausable
        if (paused()) revert();

        // require permission not revoked
        if (_isPermissionRevoked[permissionHash][batch.permission.account]) revert UnauthorizedPermission();

        // if not approved in storage, check signature approval and approve permission
        if (!_isPermissionApproved[permissionHash][batch.permission.account]) {
            if (!_isValidApprovalSignature(batch.permission.account, permissionHash, batch.permission.approval)) {
                revert();
            }

            _approvePermission(batch.permission);
        }

        // check permission contract enabled
        if (!isPermissionContractEnabled[batch.permission.permissionContract]) revert();

        // validate permission-specific logic
        IPermissionContract(batch.permission.permissionContract).validatePermissionedBatch(
            batch.permission.account, permissionHash, batch.permission.permissionValues, batch.calls
        );

        // check cosigner
        address cosigner = ECDSA.recover(batchHash, batch.cosignerSignature);
        if (!isCosignerEnabled[cosigner]) revert();

        // check calls do not re-enter account or this contract
        uint256 callsLen = batch.calls.length;
        for (uint256 i = 1; i < callsLen; i++) {
            // prevent Smart Wallet and SessionKeySender direct re-entrancy
            if (batch.calls[i].target == batch.permission.account || batch.calls[i].target == address(this)) {
                revert();
            }
        }

        // execute calls batch on account
        CoinbaseSmartWallet(payable(batch.permission.account)).executeBatch(batch.calls);
    }

    /// @notice Create Smart Wallet and then call `executeBatch` on it.
    ///
    /// @dev This contract must be in owners initialization array.
    function createAccountAndForwardBatch(bytes[] calldata owners, uint256 nonce, PermissionedBatch calldata batch)
        external
    {
        // deploy account
        factory.createAccount(owners, nonce);

        // forward batch
        forwardBatch(batch);
    }

    /// @notice Approve a permission to enable its use in user operations.
    ///
    /// @dev Entire Permission struct taken as argument for indexers to cache relevant data.
    /// @dev Permissions can also be validated just-in-time via approval signatures instead of approval storage.
    /// @dev This can be called by anyone after an approval signature has been used for gas optimization.
    ///
    /// @param permission Details of the permission.
    function approvePermission(Permission calldata permission) public {
        bytes32 permissionHash = hashPermission(permission);

        // early return if permission is already approved
        if (_isPermissionApproved[permissionHash][permission.account]) {
            return;
        }

        // check sender is permission account or approval signature is valid for permission account
        if (
            msg.sender != permission.account
                && !_isValidApprovalSignature(permission.account, permissionHash, permission.approval)
        ) {
            revert UnauthorizedPermission();
        }

        _approvePermission(permission);
    }

    /// @notice Revoke a permission to disable its use indefinitely.
    ///
    /// @dev Depending on permission contract implementation, permissions can revoke other permissions.
    ///
    /// @param permissionHash hash of the permission to revoke
    function revokePermission(bytes32 permissionHash) external {
        // early return if permission is already revoked
        if (_isPermissionRevoked[permissionHash][msg.sender]) {
            return;
        }

        _isPermissionRevoked[permissionHash][msg.sender] = true;
        emit PermissionRevoked(msg.sender, permissionHash);
    }

    /// @notice Set permission contract enabled status.
    ///
    /// @param cosigner Second factor verifier leveraging offchain validation.
    /// @param enabled The new setting allowing/preventing use.
    function updateCosigner(address cosigner, bool enabled) external onlyOwner {
        isCosignerEnabled[cosigner] = enabled;
        emit CosignerUpdated(cosigner, enabled);
    }

    /// @notice Set permission contract enabled status.
    ///
    /// @param permissionContract Contract resposible for checking permission logic.
    /// @param enabled The new setting allowing/preventing use.
    function updatePermissionContract(address permissionContract, bool enabled) external onlyOwner {
        isPermissionContractEnabled[permissionContract] = enabled;
        emit PermissionContractUpdated(permissionContract, enabled);
    }

    /// @notice Set paymaster enabled status.
    ///
    /// @dev Must explicitly set address(0) as enabled to support no-paymaster userOps.
    ///
    /// @param paymaster ERC-4337 paymaster contract.
    /// @param enabled The new setting allowing/preventing use.
    function updatePaymaster(address paymaster, bool enabled) external onlyOwner {
        isPaymasterEnabled[paymaster] = enabled;
        emit PaymasterUpdated(paymaster, enabled);
    }

    /// @notice Pause the manager contract from processing any userOps.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the manager contract to enable processing userOps again.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Renounce ownership of this contract.
    ///
    /// @dev Overidden to always revert to prevent accidental renouncing.
    function renounceOwnership() public view override onlyOwner {
        revert CannotRenounceOwnership();
    }

    function entryPoint() public view virtual returns (address) {
        return UserOperationLib.ENTRY_POINT_V06;
    }

    /// @notice Hash a Permission struct for signing.
    ///
    /// @dev Important that this hash cannot be phished via EIP-191/712 or other method.
    ///
    /// @param permission Struct to hash.
    function hashPermission(Permission memory permission) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                permission.account,
                permission.expiry,
                keccak256(permission.signer),
                permission.permissionContract,
                keccak256(permission.permissionValues),
                block.chainid, // prevent cross-chain replay
                address(this) // prevent cross-manager replay
            )
        );
    }

    function hashPermissionedBatch(bytes32 permissionHash, CoinbaseSmartWallet.Call[] memory calls)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(permissionHash, keccak256(abi.encode(calls))));
    }

    /// @notice Approve and initialize a permission.
    ///
    /// @param permission Struct containing permission details.
    function _approvePermission(Permission memory permission) internal {
        bytes32 permissionHash = hashPermission(permission);

        _isPermissionApproved[permissionHash][permission.account] = true;
        emit PermissionApproved(permission.account, permissionHash);

        // initialize permission via external call to permission contract
        IPermissionContract(permission.permissionContract).initializePermission(
            permission.account, permissionHash, permission.permissionValues
        );
    }

    /// @notice Check if a permission approval signature is valid.
    ///
    /// @param account Smart account this permission is valid for.
    /// @param permissionHash Hash of the permission.
    /// @param approval Signature bytes signed by account owner.
    ///
    /// @return isValid True if approval signature is valid.
    function _isValidApprovalSignature(address account, bytes32 permissionHash, bytes memory approval)
        internal
        view
        returns (bool)
    {
        // early return false if approval is zero-length, otherwise validate via ERC-1271 on account
        return
            approval.length != 0 && IERC1271(account).isValidSignature(permissionHash, approval) == EIP1271_MAGIC_VALUE;
    }
}
