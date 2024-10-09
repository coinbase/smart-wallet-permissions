// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract RevokeTest is Test, SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_revoke_revert_invalidSender(
        address sender,
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(sender != address(0));
        vm.assume(sender != account);
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.prank(account);
        mockSpendPermissions.approve(recurringAllowance);
        assertTrue(mockSpendPermissions.isAuthorized(recurringAllowance));
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissions.InvalidSender.selector, account));
        mockSpendPermissions.revoke(recurringAllowance);
        vm.stopPrank();
    }

    function test_revoke_success_isNoLongerAuthorized(
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.startPrank(account);
        mockSpendPermissions.approve(recurringAllowance);
        assertTrue(mockSpendPermissions.isAuthorized(recurringAllowance));
        mockSpendPermissions.revoke(recurringAllowance);
        assertFalse(mockSpendPermissions.isAuthorized(recurringAllowance));
    }

    function test_revoke_success_emitsEvent(
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.startPrank(account);
        mockSpendPermissions.approve(recurringAllowance);
        assertTrue(mockSpendPermissions.isAuthorized(recurringAllowance));
        vm.expectEmit(address(mockSpendPermissions));
        emit SpendPermissions.RecurringAllowanceRevoked({
            hash: mockSpendPermissions.getHash(recurringAllowance),
            account: account,
            recurringAllowance: recurringAllowance
        });
        mockSpendPermissions.revoke(recurringAllowance);
    }
}
