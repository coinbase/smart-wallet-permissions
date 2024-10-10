// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract ApproveTest is SpendPermissionsBase {
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

        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissions.InvalidSender.selector, account));
        mockSpendPermissions.approve(recurringAllowance);
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
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.prank(account);
        mockSpendPermissions.approve(recurringAllowance);
        vm.assertTrue(mockSpendPermissions.isAuthorized(recurringAllowance));
    }

    function test_approve_success_emitsEvent(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
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
        emit SpendPermissions.RecurringAllowanceApproved({
            hash: mockSpendPermissions.getHash(recurringAllowance),
            account: account,
            recurringAllowance: recurringAllowance
        });
        mockSpendPermissions.approve(recurringAllowance);
    }
}
