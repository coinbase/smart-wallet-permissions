// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title IPermissionContract
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
interface IPermissionContract {
    /// @notice Validate the permissions for a session.
    ///
    /// @param hash, hash of arbitrary data being validated.
    /// @param sessionHash, hash of the Session struct this permission check is validating.
    /// @param permissionData, dynamic data stored in the session for validation.
    /// @param requestData, dynamic data about the request to prove validation.
    ///
    /// @dev Reverts if validation does not pass; worth considering returning a magic-value.
    function validatePermission(
        address account,
        bytes32 hash,
        bytes32 sessionHash, 
        bytes calldata permissionData, 
        bytes calldata requestData
    ) external view returns (uint256 validationData);
}
