// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import {PermissionCallable} from "smart-wallet-permissions/mixins/PermissionCallable.sol";

/// @title SimpleSandbox
///
/// @notice Forwards any external calls to a specified target.
///
/// @dev This pattern works for target contracts that do not care who `msg.sender` is.
contract SimpleSandbox is PermissionCallable {
    /// @notice Call a target contract with data.
    ///
    /// @param target Address of contract to call.
    /// @param data Bytes to send in contract call.
    ///
    /// @return res Bytes result from the call.
    function sandboxedCall(address target, bytes calldata data) external payable returns (bytes memory) {
        return Address.functionCallWithValue(target, data, msg.value);
    }

    /// @inheritdoc PermissionCallable
    function supportsPermissionedCallSelector(bytes4 selector) public pure override returns (bool) {
        return selector == SimpleSandbox.sandboxedCall.selector;
    }
}
