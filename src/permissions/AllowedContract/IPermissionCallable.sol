// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title IPermissionCallable
///
/// @notice Interface for external contracts to support Session Keys permissionlessly.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
interface IPermissionCallable {
    /// @notice Wrap a call to the contract with a new selector.
    ///
    /// @dev Implementing contracts are encouraged to filter selectors not appropriate for Session Key use cases.
    ///
    /// @param call Call data exactly matching an existing selector+arguments on the target contract.
    function permissionedCall(bytes calldata call) external payable returns (bytes memory);
}
