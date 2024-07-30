// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title IPermissionCallable
///
/// @notice Interface for external contracts to support Session Keys permissionlessly.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
interface IPermissionCallable {
    /// @notice Wrap a call to the contract with permission data (hash and arguments).
    ///
    /// @param permissionHash, the hash of the currently active Permission
    /// @param permissionArgs, the arguments approved by the user just for this contract
    /// @param call, the call data to use
    function callWithPermission(bytes32 permissionHash, bytes calldata permissionArgs, bytes calldata call)
        external
        payable
        returns (bytes memory);
}
