// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title IPermissionModule
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
interface IPermissionModule {
    /// @notice Validate the permissions for a session.
    ///
    /// @param account, the EIP-4337 account validating for.
    /// @param sessionId, hash of the Session struct this permission check is validating.
    /// @param permissionData, dynamic data stored in the session for validation.
    /// @param requestData, dynamic data about the request to prove validation.
    ///
    /// @dev Reverts if validation does not pass; worth considering returning a magic-value.
    function validatePermissions(address account, bytes32 hash, bytes32 sessionId, bytes calldata permissionData, bytes calldata requestData) external view;
}
