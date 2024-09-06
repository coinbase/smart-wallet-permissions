// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Errors} from "openzeppelin-contracts/contracts/utils/Errors.sol";

import {PermissionCallable} from "../../../../src/mixins/PermissionCallable.sol";

import {MockPermissionCallable} from "../../../mocks/MockPermissionCallable.sol";

contract PermissionedCallTest is Test {
    MockPermissionCallable mockPermissionCallable;

    function setUp() public {
        mockPermissionCallable = new MockPermissionCallable();
    }

    function test_permissionedCall_revert_InvalidCallLength(bytes memory call) public {
        vm.assume(call.length < 4);
        vm.expectRevert(abi.encodeWithSelector(PermissionCallable.InvalidCallLength.selector));
        mockPermissionCallable.permissionedCall(call);
    }

    function test_permissionedCall_revert_notPermissionCallable() public {
        bytes4 selector = MockPermissionCallable.notPermissionCallable.selector;
        vm.expectRevert(abi.encodeWithSelector(PermissionCallable.NotPermissionCallable.selector, selector));
        mockPermissionCallable.permissionedCall(abi.encodeWithSelector(selector));
    }

    function test_permissionedCall_revert_notPermissionCallable_fuzz(bytes memory call) public {
        vm.assume(call.length >= 4);
        bytes4 selector = bytes4(call);
        vm.assume(selector != MockPermissionCallable.revertNoData.selector);
        vm.assume(selector != MockPermissionCallable.revertWithData.selector);
        vm.assume(selector != MockPermissionCallable.successNoData.selector);
        vm.assume(selector != MockPermissionCallable.successWithData.selector);
        vm.expectRevert(abi.encodeWithSelector(PermissionCallable.NotPermissionCallable.selector, selector));
        mockPermissionCallable.permissionedCall(call);
    }

    function test_permissionedCall_revert_noData() public {
        bytes4 selector = MockPermissionCallable.revertNoData.selector;
        vm.expectRevert(Errors.FailedCall.selector);
        mockPermissionCallable.permissionedCall(abi.encodeWithSelector(selector));
    }

    function test_permissionedCall_revert_withData(bytes memory revertData) public {
        bytes4 selector = MockPermissionCallable.revertWithData.selector;
        vm.expectRevert(revertData);
        mockPermissionCallable.permissionedCall(abi.encodeWithSelector(selector, revertData));
    }

    function test_permissionedCall_success_noData() public {
        bytes4 selector = MockPermissionCallable.successNoData.selector;
        bytes memory res = mockPermissionCallable.permissionedCall(abi.encodeWithSelector(selector));
        assertEq(res, bytes(""));
    }

    function test_permissionedCall_success_withData(bytes memory resData) public {
        bytes4 selector = MockPermissionCallable.successWithData.selector;
        bytes memory res = mockPermissionCallable.permissionedCall(abi.encodeWithSelector(selector, resData));
        assertEq(res, abi.encode(resData));
    }
}
