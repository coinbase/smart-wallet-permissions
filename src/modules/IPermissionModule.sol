// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title IScopeVerifier
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
interface IPermissionModule {
    function validatePermissions(address account, bytes32 hash, bytes32 sessionId, bytes calldata permissionData, bytes calldata requestData) external view;
}
