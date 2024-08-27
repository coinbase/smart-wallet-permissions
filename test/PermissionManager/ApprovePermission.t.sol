// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManager, PermissionManagerBase} from "./PermissionManagerBase.sol";

contract ApprovePermissionTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_approvePermission_revert_notSenderOrSigned(address sender) public {
        vm.assume(sender != address(account));

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        bytes32 replaySafeHash = permissionHash; // invalid hash, should be account.replaySafeHash(permissionHash)

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, replaySafeHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory approval = account.wrapSignature(0, signature);

        permission.approval = approval;

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(PermissionManager.UnauthorizedPermission.selector));
        permissionManager.approvePermission(permission);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), false);
    }

    function test_approvePermission_success_senderIsAccount() public {
        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);

        vm.startPrank(address(account));
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionApproved(address(account), permissionHash);
        permissionManager.approvePermission(permission);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_approvePermission_success_validApprovalSignature(address sender) public {
        vm.assume(sender != address(account));

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        bytes32 replaySafeHash = account.replaySafeHash(permissionHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, replaySafeHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory approval = account.wrapSignature(0, signature);

        permission.approval = approval;

        vm.startPrank(sender);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionApproved(address(account), permissionHash);
        permissionManager.approvePermission(permission);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_approvePermission_success_replay() public {
        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);

        vm.startPrank(address(account));
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionApproved(address(account), permissionHash);
        permissionManager.approvePermission(permission);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);

        // no revert on replay approval
        permissionManager.approvePermission(permission);
    }
}
