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
    /// @dev Call data exactly matches valid selector+arguments on this contract.
    /// @dev Call data matching required because this performs a self-delegatecall.
    ///
    /// @param call Call data exactly matching valid selector+arguments on this contract.
    ///
    /// @return res data returned from the inner self-delegatecall.
    function permissionedCall(bytes calldata call) external payable returns (bytes memory res);

    /// @notice Determine if a function selector is allowed via permissionedCall on this contract.
    ///
    /// @param selector the specific function to check support for.
    ///
    /// @return supported indicator if the selector is supported.
    function supportsPermissionedCallSelector(bytes4 selector) external view returns (bool supported);
}
