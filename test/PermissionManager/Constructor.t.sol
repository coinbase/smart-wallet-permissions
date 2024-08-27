// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManager, PermissionManagerBase} from "./PermissionManagerBase.sol";

contract ConstructorTest is Test, PermissionManagerBase {
    function setUp() public {}

    function test_constructor_revert_zeroOwner(address cosigner) public {
        vm.assume(cosigner != address(0));
        vm.expectRevert();
        new PermissionManager(address(0), cosigner);
    }

    function test_constructor_revert_zeroCosigner(address owner) public {
        vm.assume(owner != address(0));
        vm.expectRevert();
        new PermissionManager(owner, address(0));
    }

    function test_constructor_success(address owner, address cosigner) public {
        vm.assume(owner != address(0) && cosigner != address(0));
        PermissionManager manager = new PermissionManager(owner, cosigner);
        vm.assertEq(manager.owner(), owner);
        vm.assertEq(manager.cosigner(), cosigner);
    }
}
