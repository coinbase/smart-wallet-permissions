// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PermissionCallable} from "../../src/permissions/PermissionCallable/PermissionCallable.sol";

contract MockAllowedContract is PermissionCallable {
    function mock() public {}

    function supportsPermissionedCallSelector(bytes4) public pure override returns (bool) {
        return true;
    }

    function getMockPermissionedCallData() public pure returns (bytes memory) {
        bytes memory callData = abi.encodeWithSignature("mock()");
        bytes memory permissionedCallData =
            abi.encodeWithSelector(PermissionCallable.permissionedCall.selector, callData);
        return permissionedCallData;
    }
}
