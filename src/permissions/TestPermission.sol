// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPermissionContract} from "./IPermissionContract.sol";

/// @title TestPermission
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract TestPermission is IPermissionContract {
    /// @notice Always allow permission to pass.
    function validatePermission(
        address /*account*/,
        bytes32 /*hash*/,
        bytes32 /*sessionHash*/, 
        bytes calldata /*permissionData*/, 
        bytes calldata /*requestData*/
    ) external pure returns (uint256 validationData) {
        // no checks, just return 0 for valid validationData
        return 0;
    }
}
