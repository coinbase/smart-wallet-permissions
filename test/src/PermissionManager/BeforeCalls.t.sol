// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";

import {PermissionManager} from "../../../src/PermissionManager.sol";

import {PermissionManagerBase} from "../../base/PermissionManagerBase.sol";

contract BeforeCallsTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_beforeCalls_revert_paused() public {
        PermissionManager.Permission memory permission = _createPermission();

        vm.prank(owner);
        permissionManager.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        permissionManager.beforeCalls(permission, cosigner);
    }

    function test_beforeCalls_revert_expired(uint48 expiry) public {
        vm.assume(expiry < type(uint48).max);

        PermissionManager.Permission memory permission = _createPermission();
        permission.expiry = expiry;

        vm.warp(expiry + 1);
        vm.expectRevert(abi.encodeWithSelector(PermissionManager.ExpiredPermission.selector, expiry));
        permissionManager.beforeCalls(permission, cosigner);
    }

    function test_beforeCalls_revert_disabledPermissionContract(address permissionContract) public {
        PermissionManager.Permission memory permission = _createPermission();

        permission.permissionContract = permissionContract;

        vm.prank(owner);
        permissionManager.setPermissionContractEnabled(permissionContract, false);

        vm.expectRevert(
            abi.encodeWithSelector(PermissionManager.DisabledPermissionContract.selector, permissionContract)
        );
        permissionManager.beforeCalls(permission, cosigner);
    }

    function test_beforeCalls_revert_zeroCosigner() public {
        address userOpCosigner = address(0);

        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidCosigner.selector, userOpCosigner));
        permissionManager.beforeCalls(permission, userOpCosigner);
    }

    function test_beforeCalls_revert_invalidCosigner(address paymaster, address userOpCosigner) public {
        vm.assume(cosigner != userOpCosigner);

        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidCosigner.selector, userOpCosigner));
        permissionManager.beforeCalls(permission, userOpCosigner);
    }

    function test_beforeCalls_revert_unauthorizedPermission() public {
        PermissionManager.Permission memory permission = _createPermission();
        permission.approval = hex"";

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.UnauthorizedPermission.selector));
        permissionManager.beforeCalls(permission, cosigner);
    }

    function test_beforeCalls_success_senderIsAccount() public {
        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        vm.stopPrank();

        vm.prank(permission.account);
        permissionManager.beforeCalls(permission, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_beforeCalls_success_emitsEvent() public {
        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        vm.stopPrank();

        vm.prank(permission.account);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionApproved(address(account), permissionHash);
        permissionManager.beforeCalls(permission, cosigner);
    }

    function test_beforeCalls_success_validApprovalSignature(address sender) public {
        PermissionManager.Permission memory permission = _createPermission();
        vm.assume(sender != permission.account);

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        vm.stopPrank();

        bytes32 permissionHash = permissionManager.hashPermission(permission);
        bytes32 replaySafeHash = account.replaySafeHash(permissionHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, replaySafeHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory approval = account.wrapSignature(0, signature);

        permission.approval = approval;

        vm.prank(sender);
        permissionManager.beforeCalls(permission, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_beforeCalls_success_cosigner() public {
        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        vm.stopPrank();

        vm.prank(permission.account);
        permissionManager.beforeCalls(permission, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_beforeCalls_success_pendingCosigner(address paymaster, address newCosigner) public {
        vm.assume(paymaster != address(0));
        vm.assume(newCosigner != address(0));

        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        permissionManager.setPendingCosigner(newCosigner);
        vm.stopPrank();

        vm.prank(permission.account);
        permissionManager.beforeCalls(permission, newCosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_beforeCalls_success_replay() public {
        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        vm.stopPrank();

        vm.prank(permission.account);
        permissionManager.beforeCalls(permission, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);

        // replay without calling from account or approval signature
        permission.approval = hex"";
        permissionManager.beforeCalls(permission, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }
}
