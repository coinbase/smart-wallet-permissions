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

/// @title ProxySender (will rename, just naming the pattern for now)
///
/// @notice An ERC-4337 account that executes Session Key User Operations on Coinbase Smart Wallets.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract ProxySender is IAccount {
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
    struct SignatureData {
        /// @dev Permission details.
        Permission permission;
        /// @dev `Permission.signer` signature of user operation hash.
        bytes sessionKeySignature;
        /// @dev `this.cosigner` or `this.pendingCosigner` signature of user operation hash.
        bytes cosignerSignature;
    }

    struct ExecutionContext {
        address account;
        bytes32 permissionHash;
        bytes approvalSignature;
        address cosigner;
        address paymaster;
        address permissionContract;
    }

    /// @notice Validation data for signature failure.
    uint256 public constant SIG_FAILED = 1;

    /// @notice Expected return value for EIP-1271 `isValidSignature` call.
    /// @dev bytes4(keccak256("isValidSignature(bytes32,bytes)"))
    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

    /// @notice Singleton factory for Coinbase Smart Wallets.
    CoinbaseSmartWalletFactory public immutable smartWalletFactory;

    /// @notice Track if permissions are revoked by accounts.
    mapping(bytes32 permissionHash => mapping(address account => bool revoked)) internal _isPermissionRevoked;

    /// @notice Track if permissions are approved by accounts via transactions.
    mapping(bytes32 permissionHash => mapping(address account => bool approved)) internal _isPermissionApproved;

    /// @notice Permission is unauthorized by either revocation or lack of approval.
    error UnauthorizedPermission();

    /// @notice Invalid signature.
    error InvalidSignature();

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

    /// @notice Constructor.
    constructor(address smartWalletFactory_) {
        smartWalletFactory = CoinbaseSmartWalletFactory(smartWalletFactory_);
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
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 /*missingAccountFunds*/ )
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        (SignatureData memory data) = abi.decode(userOp.signature, (SignatureData));

        bytes32 permissionHash = hashPermission(data.permission);
        bytes32 pUserOpHash = hashPermissionedUserOp(permissionHash, userOpHash);

        ExecutionContext memory context;
        CoinbaseSmartWallet.Call[] memory calls;

        // switch on account deployed or not
        bytes4 selector = bytes4(userOp.callData);
        if (selector == this.executeBatch.selector) {
            (context, calls) = abi.decode(userOp.callData[4:], (ExecutionContext, CoinbaseSmartWallet.Call[]));
        } else if (selector == this.createAccountAndExecuteBatch.selector) {
            bytes[] memory owners;
            uint256 nonce;
            (context, calls, owners, nonce) =
                abi.decode(userOp.callData[4:], (ExecutionContext, CoinbaseSmartWallet.Call[], bytes[], uint256));

            // check account matches counterfactual address
            if (context.account != smartWalletFactory.getAddress(owners, nonce)) return SIG_FAILED;
        } else {
            // no other selectors allowed for user operation execution
            return SIG_FAILED;
        }

        // check hash matches permission
        if (context.permissionHash != permissionHash) return SIG_FAILED;

        // check account matches permission
        if (context.account != data.permission.account) return SIG_FAILED;

        // check cosigner matches execution context
        address cosigner = ECDSA.recover(pUserOpHash, data.cosignerSignature);
        if (cosigner != context.cosigner) return SIG_FAILED;

        // check paymaster matches execution context
        if (address(bytes20(userOp.paymasterAndData)) != context.paymaster) return SIG_FAILED;

        // check permission contract matches execution context
        if (data.permission.permissionContract != context.permissionContract) return SIG_FAILED;

        // validate permission-specific logic
        // note may be hard in future to do permission contracts with associated storage because sender is manager
        try IPermissionContract(data.permission.permissionContract).validatePermission(
            permissionHash, data.permission.permissionValues, userOp
        ) {} catch {
            return SIG_FAILED;
        }

        // check permission signer signed permissioned user operation
        if (!SignatureCheckerLib.isValidSignatureNow(pUserOpHash, data.sessionKeySignature, data.permission.signer)) {
            return SIG_FAILED;
        }

        // check calls do not re-enter account or this contract
        uint256 callsLen = calls.length;
        for (uint256 i = 1; i < callsLen; i++) {
            // prevent Smart Wallet and SessionKeySender direct re-entrancy
            if (calls[i].target == data.permission.account || calls[i].target == address(this)) {
                return SIG_FAILED;
            }
        }

        // return expiry in validation data
        return _packValidationData({sigFailed: false, validUntil: data.permission.expiry, validAfter: 0});
    }

    /// @notice Call `CoinbaseSmartWallet.executeBatch` with calls.
    function executeBatch(
        bytes32 permissionHash,
        CoinbaseSmartWallet account,
        CoinbaseSmartWallet.Call[] calldata calls
    ) external onlyEntryPoint {
        // require permission not revoked
        _requireNotRevoked(permissionHash, address(account));

        // check approval

        // check paused

        // check cosigner

        // check permission contract

        // check paymaster

        // set approval

        // execute calls batch on account
        account.executeBatch(calls);
    }

    /// @notice Create Smart Wallet and then call `executeBatch` on it.
    ///
    /// @dev Must deploy account in execution phase because ERC-7562 [OP-031] only allows CREATE2 for sender in
    ///      deployment phase (https://eips.ethereum.org/EIPS/eip-7562#opcode-rules) and ERC-7562 [COD-010] prevents
    ///      EXTCODEHASH changes between deployment and validation phases so we cannot deploy in validateUserOp
    ///      (https://eips.ethereum.org/EIPS/eip-7562#code-rules).
    /// @dev This contract must be in owners initialization array.
    function createAccountAndExecuteBatch(
        bytes32 permissionHash,
        bytes[] calldata owners,
        uint256 nonce,
        CoinbaseSmartWallet.Call[] calldata calls
    ) external onlyEntryPoint {
        // deploy account
        CoinbaseSmartWallet account = smartWalletFactory.createAccount(owners, nonce);

        // require permission not revoked
        _requireNotRevoked(permissionHash, address(account));

        // check approval

        // check paused

        // check cosigner

        // check permission contract

        // check paymaster

        // set approval

        // execute calls batch on account
        account.executeBatch(calls);
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
    function setPermissionContractEnabled(address permissionContract, bool enabled) external onlyOwner {
        isPermissionContractEnabled[permissionContract] = enabled;
        emit PermissionContractUpdated(permissionContract, enabled);
    }

    /// @notice Set paymaster enabled status.
    ///
    /// @dev Must explicitly set address(0) as enabled to support no-paymaster userOps.
    ///
    /// @param paymaster ERC-4337 paymaster contract.
    /// @param enabled The new setting allowing/preventing use.
    function setPaymasterEnabled(address paymaster, bool enabled) external onlyOwner {
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

    /// @notice Hash a Permission struct for signing.
    ///
    /// @dev Important that this hash cannot be phished via EIP-191/712 or other method.
    function hashPermissionedUserOp(bytes32 permissionHash, bytes32 userOpHash) public pure returns (bytes32) {
        return keccak256(abi.encode(permissionHash, userOpHash));
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

    /// @notice Reverts if the permission is revoked.
    function _requireNotRevoked(bytes32 permissionHash, address account) internal view {
        if (_isPermissionRevoked[permissionHash][account]) revert UnauthorizedPermission();
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
