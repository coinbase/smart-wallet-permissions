// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";

/// @title IPermissionContract
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
interface IPermissionContract {
    /// @notice Validate the permissions to execute a userOp.
    ///
    /// @param permissionHash hash of the permission
    /// @param permissionData dynamic data stored in the permission for validation
    /// @param userOp user operation being attempted
    function validatePermission(bytes32 permissionHash, bytes calldata permissionData, UserOperation calldata userOp)
        external
        view;
}
