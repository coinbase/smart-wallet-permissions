// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManager} from "../../../src/PermissionManager.sol";

import {PermissionManagerBase} from "../../base/PermissionManagerBase.sol";

contract ConstructorTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializeBase();
    }

    function test_constructor_revert_zeroOwner(address cosigner) public {
        vm.assume(cosigner != address(0));
        vm.expectRevert();
        new PermissionManager(address(sessionPaymaster), address(0), cosigner);
    }

    function test_constructor_revert_zeroCosigner(address owner) public {
        vm.assume(owner != address(0));
        vm.expectRevert();
        new PermissionManager(address(sessionPaymaster), owner, address(0));
    }

    function test_constructor_revert_zeroPaymaster(address owner, address cosigner) public {
        vm.assume(owner != address(0) && cosigner != address(0));
        vm.expectRevert();
        new PermissionManager(address(0), owner, cosigner);
    }

    function test_constructor_success(address owner, address cosigner) public {
        vm.assume(owner != address(0) && cosigner != address(0));
        PermissionManager manager = new PermissionManager(address(sessionPaymaster), owner, cosigner);
        vm.assertEq(manager.owner(), owner);
        vm.assertEq(manager.cosigner(), cosigner);
    }
}
