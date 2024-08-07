// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

import {IPermissionCallable} from "./IPermissionCallable.sol";

/// @title PermissionCallable
///
/// @notice Abstract contract to add Session Key support.
///
/// @dev Uses transient storage which requires solidity >=0.8.24 and chains to support EIP-1153
///      (https://eips.ethereum.org/EIPS/eip-1153)
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
abstract contract PermissionCallable is IPermissionCallable {
    /// @notice Function does not enable calls via smart wallet permissions.
    error NotPermissionCallable();

    /// @notice Wrap a call to the contract with a new selector.
    ///
    /// @dev Implementing contracts are required to enable selectors for permissioned calls via `permissionCallable`.
    /// @dev If call batching is desired, must do so via smart wallet, not multicall-like patterns on target contract.
    ///
    /// @param call Call data exactly matching an existing selector+arguments on the target contract.
    ///
    /// @return res data from self-delegatecall on other contract function.
    function permissionedCall(bytes calldata call) external payable returns (bytes memory res) {
        // check if call selector is allowed through permissionedCall
        if (!supportsPermissionedCallSelector(bytes4(call))) revert NotPermissionCallable();

        // make self-delegatecall with provided call data
        res = Address.functionDelegateCall(address(this), call);

        return res;
    }

    function supportsPermissionedCallSelector(bytes4 selector) public view virtual returns (bool);
}
