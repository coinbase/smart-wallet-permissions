// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";

contract ApproveTest is SpendPermissionManagerBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_approve_revert_invalidSender(
        address sender,
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(sender != address(0));
        vm.assume(sender != account);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.InvalidSender.selector, account));
        mockSpendPermissions.approve(spendPermission);
        vm.stopPrank();
    }

    function test_approve_success_isAuthorized(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.prank(account);
        mockSpendPermissions.approve(spendPermission);
        vm.assertTrue(mockSpendPermissions.isAuthorized(spendPermission));
    }

    function test_approve_success_emitsEvent(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.startPrank(account);
        vm.expectEmit(address(mockSpendPermissions));
        emit SpendPermissionManager.SpendPermissionApproved({
            hash: mockSpendPermissions.getHash(spendPermission),
            account: account,
            spendPermission: spendPermission
        });
        mockSpendPermissions.approve(spendPermission);
    }
}
