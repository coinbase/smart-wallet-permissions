// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManager} from "../../../src/PermissionManager.sol";

import {PermissionManagerBase} from "../../base/PermissionManagerBase.sol";

contract RevokePermissionTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_revokePermission_success(address sender) public {
        PermissionManager.Permission memory permission = _createPermission();
        permission.account = sender;
        bytes32 permissionHash = permissionManager.hashPermission(permission);

        vm.prank(sender);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionRevoked(sender, permissionHash);
        permissionManager.revokePermission(permissionHash);
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), false);
    }

    function test_revokePermission_success_differentAccounts(address sender1, address sender2) public {
        PermissionManager.Permission memory permission = _createPermission();
        permission.account = sender1;
        bytes32 permissionHash = permissionManager.hashPermission(permission);

        vm.assume(sender1 != sender2);
        vm.prank(sender1);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionRevoked(sender1, permissionHash);
        permissionManager.revokePermission(permissionHash);
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), false);

        permission.account = sender2;
        vm.prank(sender2);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionRevoked(sender2, permissionHash);
        permissionManager.revokePermission(permissionHash);
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), false);
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), false);
    }

    function test_revokePermission_success_replaySameAccount(address sender) public {
        PermissionManager.Permission memory permission = _createPermission();
        permission.account = sender;
        bytes32 permissionHash = permissionManager.hashPermission(permission);

        vm.startPrank(sender);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionRevoked(sender, permissionHash);
        permissionManager.revokePermission(permissionHash);
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), false);
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), false);
    }
}
