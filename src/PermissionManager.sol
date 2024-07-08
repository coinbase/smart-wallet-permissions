// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {IPermissionContract} from "./permissions/IPermissionContract.sol";
import {SignatureChecker} from "./utils/SignatureChecker.sol";
import {UserOperation, UserOperationUtils} from "./utils/UserOperationUtils.sol";

/// @title PermissionManager
///
/// @notice EIP-1271-compatible permission key implementation that supports arbitrary permissions and EOA+passkey signers.
///
/// @dev Without the full UserOp and control of the execution flow, this contract only validates permission validity.
///      Some permission implementations rely on assertation calls made at the end of a batch execution to uphold constraints.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract PermissionManager is IERC1271, UserOperationUtils {
    /// @notice A time-bound permission over an account given to an external signer.
    struct Permission {
        address account;
        uint256 chainId;
        uint40 expiry;
        bytes signer; // supports EOA, smart contracts, and passkeys
        address permissionContract;
        bytes permissionData;
        address verifyingContract; // replay protection, not needed if this logic brought inside the account
        bytes approval; // signature from an account owner proving a permission is valid
    }

    /// @notice Permission account does not match currently authentication sender.
    error InvalidPermissionAccount();

    /// @notice Permission chain is not agnositc and not this chain.
    error InvalidPermissionChain();

    /// @notice Permission verifying contract is not this PermissionManager.
    error InvalidPermissionVerifyingContract();

    /// @notice Permission is revoked.
    error RevokedPermission();
    
    /// @notice Permission has expired.
    error ExpiredPermission();
    
    /// @notice PermissionApproval is invalid
    error InvalidPermissionApproval();

    /// @notice Signature from permission signer does not match hash.
    error InvalidSignature();

    /// @notice Permission was revoked prematurely by account.
    ///
    /// @param account The smart contract account the permission controlled.
    /// @param permissionHash The unique hash representing the permission.
    event PermissionRevoked(address indexed account, bytes32 indexed permissionHash);
    
    /// @dev keying storage by account in deepest mapping enables us to pass 4337 storage access limitations
    mapping(bytes32 permissionHash => mapping(address account => bool revoked)) internal _revokedPermissions;

    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

    /// @notice Validates a permission via EIP-1271.
    ///
    /// @dev Assumes called by CoinbaseSmartWallet where this contract is an owner.
    ///
    /// @param hash Arbitrary data to sign over.
    /// @param authData Combination of an approved Permission and a signature from the permission's signer for `hash`.
    function isValidSignature(bytes32 hash, bytes calldata authData) external view returns (bytes4 result) {
        // assume permission, signature, attestation encoded together
        (Permission memory permission, bytes memory signature, UserOperation memory userOp) = abi.decode(authData, (Permission, bytes, UserOperation));
        bytes32 permissionHash = hashPermission(permission);

        address account = msg.sender; // assume that we have been called by the account as part of owner signature validation
        // check userOperation sender matches account;
        _validateUserOperationSender(account, userOp.sender);
        // check userOperation matches hash
        _validateUserOperationHash(hash, userOp);
        // check chainId is this chain
        if (permission.chainId != block.chainid) revert InvalidPermissionChain();
        // check verifyingContract is PermissionManager
        if (permission.verifyingContract != address(this)) revert InvalidPermissionVerifyingContract();
        // check permission not expired
        /// @dev accessing block.timestamp will cause 4337 error, need to get override consent from bundlers, long term need to move this logic inside of account
        if (permission.expiry < block.timestamp) revert ExpiredPermission();
        // check permission not revoked
        if (_revokedPermissions[permissionHash][permission.account]) revert RevokedPermission();
        // check permission account approval
        if (EIP1271_MAGIC_VALUE != IERC1271(permission.account).isValidSignature(permissionHash, permission.approval)) revert InvalidPermissionApproval();
        // check permission signer's signature on hash
        if (!SignatureChecker.isValidSignatureNow(hash, signature, permission.signer)) revert InvalidSignature();
        // validate permission-specific logic
        IPermissionContract(permission.permissionContract).validatePermission(permissionHash, permission.permissionData, userOp);

        return EIP1271_MAGIC_VALUE;
    }

    /// @notice Revoke a permission to prematurely expire it.
    ///
    /// @dev Without a scope to mitigate, permissions can revoke other permissions.
    ///
    /// @param permissionHash hash of the permission to revoke
    function revokePermission(bytes32 permissionHash) external {
        if (_revokedPermissions[permissionHash][msg.sender]) {
            revert RevokedPermission();
        }
        _revokedPermissions[permissionHash][msg.sender] = true;

        emit PermissionRevoked(msg.sender, permissionHash);
    }

    function hashPermission(Permission memory permission) public pure returns (bytes32) {
        return keccak256(abi.encode(
            permission.account,
            permission.chainId,
            permission.expiry,
            keccak256(permission.signer),
            permission.permissionContract,
            keccak256(permission.permissionData),
            permission.verifyingContract
        ));
    }
}