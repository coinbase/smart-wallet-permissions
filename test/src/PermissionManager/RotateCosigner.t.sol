// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {PermissionManager} from "../../../src/PermissionManager.sol";

import {PermissionManagerBase} from "../../base/PermissionManagerBase.sol";

contract RotateCosignerTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_setPendingCosigner_revert_notOwner(address sender, address newCosigner) public {
        vm.assume(newCosigner != address(0));
        vm.assume(sender != owner);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.setPendingCosigner(newCosigner);
    }

    function test_setPendingCosigner_revert_zeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(PermissionManager.PendingCosignerIsZeroAddress.selector));
        permissionManager.setPendingCosigner(address(0));
    }

    function test_setPendingCosigner_success(address newCosigner) public {
        vm.assume(newCosigner != address(0));
        vm.prank(owner);
        permissionManager.setPendingCosigner(newCosigner);
        vm.assertEq(permissionManager.pendingCosigner(), newCosigner);
    }

    function test_resetPendingCosigner_revert_notOwner(address sender) public {
        vm.assume(sender != owner);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.resetPendingCosigner();
    }

    function test_resetPendingCosigner_success(address newCosigner) public {
        vm.assume(newCosigner != address(0));
        vm.startPrank(owner);
        permissionManager.setPendingCosigner(newCosigner);
        permissionManager.resetPendingCosigner();
        vm.assertEq(permissionManager.pendingCosigner(), address(0));
    }

    function test_rotateCosigner_revert_notOwner(address sender, address newCosigner) public {
        vm.assume(newCosigner != address(0));
        vm.assume(sender != owner);

        vm.prank(owner);
        permissionManager.setPendingCosigner(newCosigner);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.rotateCosigner();
    }

    function test_rotateCosigner_revert_zeroAddress() public {
        vm.startPrank(owner);
        permissionManager.resetPendingCosigner();
        vm.expectRevert(abi.encodeWithSelector(PermissionManager.PendingCosignerIsZeroAddress.selector));
        permissionManager.rotateCosigner();
    }

    function test_rotateCosigner_success(address newCosigner) public {
        vm.assume(newCosigner != address(0));
        vm.startPrank(owner);
        permissionManager.setPendingCosigner(newCosigner);
        permissionManager.rotateCosigner();
        vm.assertEq(permissionManager.cosigner(), newCosigner);
        vm.assertEq(permissionManager.pendingCosigner(), address(0));
    }
}
