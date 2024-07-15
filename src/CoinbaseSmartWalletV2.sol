// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {CoinbaseSmartWallet, UserOperation, SignatureCheckerLib, WebAuthn} from "smart-wallet/CoinbaseSmartWallet.sol";

import {SignatureChecker} from "./utils/SignatureChecker.sol";
import {IPermissionContract} from "./permissions/IPermissionContract.sol";

/// @notice **Experimental** implementation of permission management within CoinbaseSmartWallet.
///
/// @dev This is for illustrative purposes only and is not an official implementation or expectation to upgrade our account.
/// @dev The recommended launch strategy is to use PermissionManager for introducing the feature without upgrades and follow up with
///      bringing permission management into the core wallet implementation at a later date.
/// @dev Application of modular permissions to normal EIP-1271 validation was excluded for tigher scope and lack of use cases that would motivate the change.
/// @dev Modular permission contracts used in the PermissionManager approach can be re-used as-is with this implementation.
///      Users will still need to sign new permission approvals, but the existing deployed logic and state can be re-used.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract CoinbaseSmartWalletV2 is CoinbaseSmartWallet {
    /// @notice A time-bound provision of scoped account control to another signer.
    struct Permission {
        address account;
        uint256 chainId;
        uint40 expiry;
        bytes signer; // supports EOA, smart contracts, and passkeys
        address permissionContract;
        bytes permissionData;
        bytes approval; // signature from an account owner proving a permission is valid
    }

    /// @notice Permission account does not match currently authentication sender.
    error InvalidPermissionAccount();

    /// @notice Permission chain is not agnositc and not this chain.
    error InvalidPermissionChain();

    /// @notice Permission is revoked.
    error RevokedPermission();
    
    /// @notice PermissionApproval is invalid
    error InvalidPermissionApproval();

    /// @notice Signature from permission signer does not match hash.
    error InvalidSignature();

    /// @notice Permission permission check failed
    error InvalidPermissionPermission();

    /// @notice Permission was revoked prematurely by account.
    ///
    /// @param account The smart contract account the permission controlled.
    /// @param permissionHash The unique hash representing the permission.
    event PermissionRevoked(address indexed account, bytes32 indexed permissionHash);
    
    /// TODO: move to 7201 storage
    /// @dev keying storage by account in deepest mapping enables us to pass 4337 storage access limitations
    mapping(bytes32 permissionHash => bool revoked) internal _revokedPermissions;

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        virtual
        override
        onlyEntryPoint
        payPrefund(missingAccountFunds)
        returns (uint256 validationData)
    {
        uint256 key = userOp.nonce >> 64;

        if (bytes4(userOp.callData) == this.executeWithoutChainIdValidation.selector) {
            userOpHash = getUserOpHashWithoutChainId(userOp);
            if (key != REPLAYABLE_NONCE_KEY) {
                revert InvalidNonceKey(key);
            }
        } else {
            if (key == REPLAYABLE_NONCE_KEY) {
                revert InvalidNonceKey(key);
            }
        }

        // IMPORTANT: this is the new part of this override, all else is the same
        // check signature prefix against magic value to activate permission logic
        if (bytes32(userOp.signature) == 0x7715771577157715771577157715771577157715771577157715771577157715) {
            return _validatePermission(userOp, userOpHash);
        }

        // Return 0 if the recovered address matches the owner.
        if (_isValidSignature(userOpHash, userOp.signature)) {
            return 0;
        }

        // Else return 1
        return 1;
    }

    /// @notice Validates a permission
    ///
    /// @param userOp UserOperation
    /// @param userOpHash Hash of the UserOperation
    ///
    /// @return validationData data contiaining signature failure and expiry
    function _validatePermission(UserOperation memory userOp, bytes32 userOpHash) internal view returns (uint256) {
        (/*bytes32 magicValue*/, Permission memory permission, bytes memory signature) = abi.decode(userOp.signature, (bytes32, Permission, bytes));
        bytes32 permissionHash = hashPermission(permission);

        // check account matches this
        if (permission.account != address(this)) revert InvalidPermissionAccount();
        // check chainId is agnostic or this chain
        if (permission.chainId != block.chainid) revert InvalidPermissionChain();
        // check permission not revoked
        if (_revokedPermissions[permissionHash]) revert RevokedPermission();
        // check permission approval matches EIP-1271 magic value
        if (bytes4(0x1626ba7e) != IERC1271(address(this)).isValidSignature(permissionHash, permission.approval)) revert InvalidPermissionApproval();
        // TODO: replace revert with sigFailed indicator in validationData
        // check permission signer's signature on userOpHash
        if (!SignatureChecker.isValidSignatureNow(userOpHash, signature, permission.signer)) revert InvalidSignature();

        // TODO: take permission.expiry into account for the validUntil part of validationData
        // validate permission-specific logic, returns validationData for time expiry
        return IPermissionContract(permission.permissionContract).validatePermission(permissionHash, permission.permissionData, userOp);
    }

    function hashPermission(Permission memory permission) public pure returns (bytes32) {
        return keccak256(abi.encode(
            permission.account,
            permission.chainId,
            permission.expiry,
            keccak256(permission.signer),
            permission.permissionContract,
            keccak256(permission.permissionData)
        ));
    }

    /// @notice Revoke a permission to prematurely expire it.
    ///
    /// @dev Without intentional mitigation, permission signers can revoke other permissions.
    ///
    /// @param permissionHash hash of the permission to revoke
    function revokePermission(bytes32 permissionHash) external {
        if (_revokedPermissions[permissionHash]) {
            revert RevokedPermission();
        }
        _revokedPermissions[permissionHash] = true;

        emit PermissionRevoked(msg.sender, permissionHash);
    }
}