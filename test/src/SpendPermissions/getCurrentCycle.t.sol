// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract GetCurrentCycleTest is Test, SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_getCurrentCycle_revert_beforeRecurringAllowanceStart(uint48 start) public {
        vm.assume(start > 0);

        SpendPermissions.RecurringAllowance memory recurringAllowance = _createRecurringAllowance();
        recurringAllowance.start = start;
        vm.warp(start - 1);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissions.BeforeRecurringAllowanceStart.selector, start));
        mockSpendPermissions.getCurrentCycle(recurringAllowance);
    }

    function test_getCurrentCycle_revert_afterRecurringAllowanceEnd(uint48 end) public {
        vm.assume(end > 0);
        vm.assume(end < type(uint48).max);

        SpendPermissions.RecurringAllowance memory recurringAllowance = _createRecurringAllowance();
        recurringAllowance.end = end;
        vm.warp(end + 1);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissions.AfterRecurringAllowanceEnd.selector, end));
        mockSpendPermissions.getCurrentCycle(recurringAllowance);
    }

    function test_getCurrentCycle_success_unusedAllowance(
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);

        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.warp(start);
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        bool endOverflow = uint256(start) + uint256(period) > type(uint48).max;
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, 0);
    }

    function test_getCurrentCycle_success_startOfPeriod(
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(spend <= allowance);

        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(address(account));
        mockSpendPermissions.approve(recurringAllowance);

        vm.warp(start);
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, spend);
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }

    function test_getCurrentCycle_success_endOfPeriod(
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(period <= end - start);
        vm.assume(allowance > 0);
        vm.assume(spend <= allowance);

        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(address(account));
        mockSpendPermissions.approve(recurringAllowance);

        vm.warp(start);
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, spend);

        vm.warp(_safeAddUint48(start, period) - 1);
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }

    function test_getCurrentCycle_succes_resetsAfterPeriod(
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(period <= end - start);
        vm.assume(allowance > 0);
        vm.assume(spend <= allowance);

        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(address(account));
        mockSpendPermissions.approve(recurringAllowance);

        vm.warp(start);
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, spend);

        vm.warp(_safeAddUint48(start, period));
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        assertEq(usage.start, _safeAddUint48(start, period));
        assertEq(usage.end, _safeAddUint48(_safeAddUint48(start, period), period));
        assertEq(usage.spend, 0);
    }

    function test_getCurrentCycle_success_maxValueForEnd(
        address permissionSigner,
        uint48 start,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(uint256(start) + uint256(period) > type(uint48).max); // force overflow
        vm.assume(allowance > 0);

        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: type(uint48).max,
            period: period,
            allowance: allowance
        });

        vm.warp(start);
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        assertEq(usage.start, start);
        assertEq(usage.end, type(uint48).max);
        assertEq(usage.spend, 0);
    }
}
