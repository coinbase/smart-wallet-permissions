// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserOperation} from "../utils/UserOperationUtils.sol";

import {IPermissionContract} from "./IPermissionContract.sol";

/// @title TestPermission
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract TestPermission is IPermissionContract {
    /// @notice Always allow permission to pass.
    function validatePermission(
        bytes32 /*permissionHash*/, 
        bytes calldata /*permissionData*/, 
        UserOperation calldata /*userOp*/
    ) external pure returns (uint256 validationData) {
        // no checks, just return 0 for valid validationData
        return 0;
    }
}
