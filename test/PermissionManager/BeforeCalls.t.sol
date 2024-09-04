// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";

import {PermissionManager, PermissionManagerBase} from "./PermissionManagerBase.sol";

contract BeforeCallsTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_beforeCalls_revert_paused(address paymaster) public {
        PermissionManager.Permission memory permission = _createPermission();

        vm.prank(owner);
        permissionManager.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        permissionManager.beforeCalls(permission, paymaster, cosigner);
    }

    function test_beforeCalls_revert_expired(uint48 expiry, address paymaster) public {
        vm.assume(expiry < type(uint48).max);

        PermissionManager.Permission memory permission = _createPermission();
        permission.expiry = expiry;

        vm.warp(expiry + 1);
        vm.expectRevert(abi.encodeWithSelector(PermissionManager.ExpiredPermission.selector, expiry));
        permissionManager.beforeCalls(permission, paymaster, cosigner);
    }

    function test_beforeCalls_revert_disabledPermissionContract(address permissionContract, address paymaster) public {
        PermissionManager.Permission memory permission = _createPermission();

        permission.permissionContract = permissionContract;

        vm.prank(owner);
        permissionManager.setPermissionContractEnabled(permissionContract, false);

        vm.expectRevert(
            abi.encodeWithSelector(PermissionManager.DisabledPermissionContract.selector, permissionContract)
        );
        permissionManager.beforeCalls(permission, paymaster, cosigner);
    }

    function test_beforeCalls_revert_disabledPaymaster(address paymaster) public {
        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        permissionManager.setPaymasterEnabled(paymaster, false);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.DisabledPaymaster.selector, paymaster));
        permissionManager.beforeCalls(permission, paymaster, cosigner);
    }

    function test_beforeCalls_revert_noPaymaster() public {
        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.DisabledPaymaster.selector, address(0)));
        permissionManager.beforeCalls(permission, address(0), cosigner);
    }

    function test_beforeCalls_revert_invalidCosigner(address paymaster, address userOpCosigner) public {
        vm.assume(cosigner != userOpCosigner);

        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        permissionManager.setPaymasterEnabled(paymaster, true);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidCosigner.selector, userOpCosigner));
        permissionManager.beforeCalls(permission, paymaster, userOpCosigner);
    }

    function test_beforeCalls_revert_unauthorizedPermission(address paymaster) public {
        vm.assume(paymaster != address(0));

        PermissionManager.Permission memory permission = _createPermission();
        permission.approval = hex"";

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        permissionManager.setPaymasterEnabled(paymaster, true);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.UnauthorizedPermission.selector));
        permissionManager.beforeCalls(permission, paymaster, cosigner);
    }

    function test_beforeCalls_success_senderIsAccount(address paymaster) public {
        vm.assume(paymaster != address(0));

        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        permissionManager.setPaymasterEnabled(paymaster, true);
        vm.stopPrank();

        vm.prank(permission.account);
        permissionManager.beforeCalls(permission, paymaster, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_beforeCalls_success_validApprovalSignature(address sender, address paymaster) public {
        vm.assume(paymaster != address(0));

        PermissionManager.Permission memory permission = _createPermission();
        vm.assume(sender != permission.account);

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        permissionManager.setPaymasterEnabled(paymaster, true);
        vm.stopPrank();

        bytes32 permissionHash = permissionManager.hashPermission(permission);
        bytes32 replaySafeHash = account.replaySafeHash(permissionHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, replaySafeHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory approval = account.wrapSignature(0, signature);

        permission.approval = approval;

        vm.prank(sender);
        permissionManager.beforeCalls(permission, paymaster, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_beforeCalls_success_cosigner(address paymaster) public {
        vm.assume(paymaster != address(0));

        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        permissionManager.setPaymasterEnabled(paymaster, true);
        vm.stopPrank();

        vm.prank(permission.account);
        permissionManager.beforeCalls(permission, paymaster, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_beforeCalls_success_pendingCosigner(address paymaster, address newCosigner) public {
        vm.assume(paymaster != address(0));

        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        permissionManager.setPaymasterEnabled(paymaster, true);
        permissionManager.setPendingCosigner(newCosigner);
        vm.stopPrank();

        vm.prank(permission.account);
        permissionManager.beforeCalls(permission, paymaster, newCosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }

    function test_beforeCalls_success_replay(address paymaster) public {
        vm.assume(paymaster != address(0));

        PermissionManager.Permission memory permission = _createPermission();

        vm.startPrank(owner);
        permissionManager.setPermissionContractEnabled(permission.permissionContract, true);
        permissionManager.setPaymasterEnabled(paymaster, true);
        vm.stopPrank();

        vm.prank(permission.account);
        permissionManager.beforeCalls(permission, paymaster, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);

        // replay without calling from account or approval signature
        permission.approval = hex"";
        permissionManager.beforeCalls(permission, paymaster, cosigner);

        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
        permission.approval = hex"";
        vm.assertEq(permissionManager.isPermissionAuthorized(permission), true);
    }
}
