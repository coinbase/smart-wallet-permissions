// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";

/// @title IPermissionContract
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
interface IPermissionContract {
    /// @notice Validate the permission to execute a userOp.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param permissionFields Additional arguments for validation.
    /// @param userOp User operation to validate permission for.
    function validatePermission(bytes32 permissionHash, bytes calldata permissionFields, UserOperation calldata userOp)
        external
        view;

    /// @notice Initialize the permission fields.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param permissionFields Additional arguments for validation.
    function initializePermission(bytes32 permissionHash, bytes calldata permissionFields) external;
}
