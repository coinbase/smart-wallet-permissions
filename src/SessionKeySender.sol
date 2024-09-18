// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

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

/// @title SessionKeySender
///
/// @notice A dynamic permission system built into an EIP-1271 module designed for Coinbase Smart Wallet
///         (https://github.com/coinbase/smart-wallet).
///
/// @dev This is a staked ERC-4337 account that all Session Key User Operations will flow through.
/// @dev Staked accounts can submit unlimited User Operations
/// @dev ERC-7562 [EREP-030] holds staked accounts accountable for failures in other entities (paymaster, aggregator)
///      even if they are staked (https://eips.ethereum.org/EIPS/eip-7562#entity-specific-rules). This means that we
///      have DOS risk if paymasters or aggregators are failing via triggering throttling of this sender.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract SessionKeySender is IAccount, Ownable2Step, Pausable {
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

    /// @notice Singleton factory for Coinbase Smart Wallets.
    CoinbaseSmartWalletFactory public immutable factory;

    /// @notice Track if permission contracts are enabled.
    ///
    /// @dev Storage not keyable by account, can only be accessed in execution phase.
    mapping(address permissionContract => bool enabled) public isPermissionContractEnabled;

    /// @notice Track if cosigner is enabled.
    mapping(address cosigner => bool enabled) public isCosignerEnabled;

    /// @notice Track if permissions are revoked by accounts.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 permissionHash => mapping(address account => bool revoked)) internal _isPermissionRevoked;

    /// @notice Track if permissions are approved by accounts via transactions.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 permissionHash => mapping(address account => bool approved)) internal _isPermissionApproved;

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

    /// @notice Reverts if the permission is revoked.
    modifier notRevoked(bytes32 permissionHash) {
        if (_isPermissionRevoked[permissionHash]) revert();

        _;
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 /*missingAccountFunds*/ )
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        (SignatureData memory data) = abi.decode(userOp.signature, (SignatureData));

        // check pausable
        // note at risk of accidental DOS
        // TODO

        // switch on account deployed or not
        // TODO

        // compare permission account with executing account
        // TODO

        // check permission approved
        // TODO

        // approve permission if not yet approved
        // TODO

        // check permission signer signed permissioned user operation
        // note at risk of accidental DOS if stateful contract signer allowed
        bytes32 pUserOpHash = hashPermissionedUserOp(data.permission, userOp);
        if (!SignatureCheckerLib.isValidSignatureNow(pUserOpHash, data.sessionKeySignature, data.permission.signer)) {
            revert InvalidSignature();
        }

        // check cosigner is enabled
        // note at risk of accidental DOS if state disabled
        // note must be in validation phase to prevent malicious paymaster DOS attack
        address cosigner = ECDSA.recover(pUserOpHash, data.cosignerSignature);
        if (!isCosignerEnabled[cosigner]) revert();

        // check permission contract enabled
        // note at risk of accidental DOS if state disabled
        // note must be in validation phase to prevent malicious paymaster DOS attack
        // TODO

        // validate permission-specific logic
        // note at risk of accidental DOS
        IPermissionContract(data.permission.permissionContract).validatePermission(
            permissionHash, data.permission.permissionValues, data.userOp
        );

        // check paymaster enabled
        // note at risk of accidental DOS if state disabled
        // TODO

        // prevent account reenntrancy
        // TODO

        // prevent manager reentrancy
        // TODO

        // return expiry in validation data
        // TODO
    }

    /// @notice Create Smart Wallet and then call `executeBatch` on it.
    ///
    /// @dev Must deploy account in execution phase because ERC-7562 [OP-031] only allows CREATE2 for sender in
    ///      deployment phase (https://eips.ethereum.org/EIPS/eip-7562#opcode-rules) and ERC-7562 [COD-010] prevents
    ///      EXTCODEHASH changes between deployment and validation phases so we cannot deploy in validateUserOp
    ///      (https://eips.ethereum.org/EIPS/eip-7562#code-rules).
    function createAccountAndExecuteBatch(
        bytes32 permissionHash,
        bytes[] calldata owners,
        uint256 nonce,
        CoinbaseSmartWallet.Call[] calldata calls
    ) external notRevoked(permissionHash) {
        factory.createAccount(owners, nonce).executeBatch(calls);
    }

    /// @notice Call `CoinbaseSmartWallet.executeBatch` with calls.
    function executeBatch(
        bytes32 permissionHash,
        CoinbaseSmartWallet account,
        CoinbaseSmartWallet.Call[] calldata calls
    ) external notRevoked(permissionHash) {
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

        _isPermissionApproved[permissionHash][permission.account] = true;
        emit PermissionApproved(permission.account, permissionHash);

        // initialize permission via external call to permission contract
        IPermissionContract(permission.permissionContract).initializePermission(
            permission.account, permissionHash, permission.permissionValues
        );
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
    /// @param permissionContract The contract resposible for checking permission logic.
    /// @param enabled True if the contract is enabled.
    function setPermissionContractEnabled(address permissionContract, bool enabled) external onlyOwner {
        isPermissionContractEnabled[permissionContract] = enabled;
        emit PermissionContractUpdated(permissionContract, enabled);
    }

    /// @notice Set paymaster enabled status.
    ///
    /// @dev Must explicitly set address(0) as enabled to support no-paymaster userOps.
    ///
    /// @param paymaster ERC-4337 paymaster contract.
    /// @param enabled True if the contract is enabled.
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
    ///
    /// @param permission Struct to hash.
    function hashPermissionedUserOp(Permission memory permission, UserOperation memory userOp)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(hashPermission(permission), UserOperationLib.getUserOpHash(userOp)));
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
