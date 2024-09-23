// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

/// @title IPermissionContract
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
interface IPermissionContract {
    /// @notice Sender for intializePermission was not permission manager.
    error InvalidInitializePermissionSender(address sender);

    /// @notice Validate the permission to execute a userOp.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param permissionValues Additional arguments for validation.
    /// @param userOp User operation to validate permission for.
    function validatePermission(bytes32 permissionHash, bytes calldata permissionValues, UserOperation calldata userOp)
        external
        view;

    /// @notice Validate the permission to execute a userOp.
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    /// @param permissionValues Additional arguments for validation.
    /// @param calls Calls to batch execute.
    function validatePermissionedBatch(
        address account,
        bytes32 permissionHash,
        bytes calldata permissionValues,
        CoinbaseSmartWallet.Call[] calldata calls
    ) external;

    /// @notice Initialize a permission with its verified values.
    ///
    /// @dev Some permissions require state which is initialized upon first use/approval.
    /// @dev Can only be called by the PermissionManager.
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    /// @param permissionValues Additional arguments for validation.
    function initializePermission(address account, bytes32 permissionHash, bytes calldata permissionValues) external;
}
