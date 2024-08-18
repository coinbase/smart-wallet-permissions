// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

import {IPermissionCallable} from "./interfaces/IPermissionCallable.sol";

/// @title PermissionCallable
///
/// @notice Abstract contract to add permissioned userOp support to smart contracts.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
abstract contract PermissionCallable is IPermissionCallable {
    /// @notice Call not enabled through permissionedCall and smart wallet permissions systems.
    ///
    /// @param selector The function that was attempting to go through permissionedCall.
    error NotPermissionCallable(bytes4 selector);

    /// @inheritdoc IPermissionCallable
    function permissionedCall(bytes calldata call) external payable returns (bytes memory res) {
        // check if call selector is allowed through permissionedCall
        if (!supportsPermissionedCallSelector(bytes4(call))) revert NotPermissionCallable(bytes4(call));
        // make self-delegatecall with provided call data
        return Address.functionDelegateCall(address(this), call);
    }

    /// @inheritdoc IPermissionCallable
    function supportsPermissionedCallSelector(bytes4 selector) public view virtual returns (bool);
}
