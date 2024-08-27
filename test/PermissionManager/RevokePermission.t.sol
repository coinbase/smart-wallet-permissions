// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManager, PermissionManagerBase} from "./PermissionManagerBase.sol";

contract RevokePermissionTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_revokePermission_success(address sender, bytes32 permissionHash) public {
        vm.prank(sender);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionRevoked(sender, permissionHash);
        permissionManager.revokePermission(permissionHash);
        vm.assertEq(permissionManager.isPermissionRevoked(permissionHash, sender), true);
    }

    function test_revokePermission_success_differentAccounts(address sender1, address sender2, bytes32 permissionHash)
        public
    {
        vm.assume(sender1 != sender2);
        vm.prank(sender1);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionRevoked(sender1, permissionHash);
        permissionManager.revokePermission(permissionHash);
        vm.assertEq(permissionManager.isPermissionRevoked(permissionHash, sender1), true);
        vm.assertEq(permissionManager.isPermissionRevoked(permissionHash, sender2), false);

        vm.prank(sender2);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionRevoked(sender2, permissionHash);
        permissionManager.revokePermission(permissionHash);
        vm.assertEq(permissionManager.isPermissionRevoked(permissionHash, sender1), true);
        vm.assertEq(permissionManager.isPermissionRevoked(permissionHash, sender2), true);
    }

    function test_revokePermission_success_replaySameAccount(address sender, bytes32 permissionHash) public {
        vm.startPrank(sender);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionRevoked(sender, permissionHash);
        permissionManager.revokePermission(permissionHash);
        vm.assertEq(permissionManager.isPermissionRevoked(permissionHash, sender), true);
        vm.assertEq(permissionManager.isPermissionRevoked(permissionHash, sender), true);
    }
}
