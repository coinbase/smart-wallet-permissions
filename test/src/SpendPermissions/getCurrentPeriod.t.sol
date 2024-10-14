// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";

contract GetCurrentCycleTest is SpendPermissionManagerBase {
    function setUp() public {
        _initializeSpendPermissionManager();
    }

    function test_getCurrentPeriod_revert_beforeSpendPermissionStart(uint48 start) public {
        vm.assume(start > 0);

        SpendPermissionManager.SpendPermission memory spendPermission = _createSpendPermission();
        spendPermission.start = start;
        vm.warp(start - 1);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.BeforeSpendPermissionStart.selector, start));
        mockSpendPermissionManager.getCurrentPeriod(spendPermission);
    }

    function test_getCurrentPeriod_revert_afterSpendPermissionEnd(uint48 end) public {
        vm.assume(end > 0);
        vm.assume(end < type(uint48).max);

        SpendPermissionManager.SpendPermission memory spendPermission = _createSpendPermission();
        spendPermission.end = end;
        vm.warp(end + 1);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.AfterSpendPermissionEnd.selector, end));
        mockSpendPermissionManager.getCurrentPeriod(spendPermission);
    }

    function test_getCurrentPeriod_success_unusedAllowance(
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

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.warp(start);
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissionManager.getCurrentPeriod(spendPermission);

        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, 0);
    }

    function test_getCurrentPeriod_success_startOfPeriod(
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

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(address(account));
        mockSpendPermissionManager.approve(spendPermission);

        vm.warp(start);
        mockSpendPermissionManager.useSpendPermission(spendPermission, spend);
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissionManager.getCurrentPeriod(spendPermission);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }

    function test_getCurrentPeriod_success_endOfPeriod(
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

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(address(account));
        mockSpendPermissionManager.approve(spendPermission);

        vm.warp(start);
        mockSpendPermissionManager.useSpendPermission(spendPermission, spend);

        vm.warp(_safeAddUint48(start, period) - 1);
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissionManager.getCurrentPeriod(spendPermission);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }

    function test_getCurrentPeriod_succes_resetsAfterPeriod(
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

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(address(account));
        mockSpendPermissionManager.approve(spendPermission);

        vm.warp(start);
        mockSpendPermissionManager.useSpendPermission(spendPermission, spend);

        vm.warp(_safeAddUint48(start, period));
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissionManager.getCurrentPeriod(spendPermission);
        assertEq(usage.start, _safeAddUint48(start, period));
        assertEq(usage.end, _safeAddUint48(_safeAddUint48(start, period), period));
        assertEq(usage.spend, 0);
    }

    function test_getCurrentPeriod_success_maxValueForEnd(
        address permissionSigner,
        uint48 start,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(uint256(start) + uint256(period) > type(uint48).max); // force overflow
        vm.assume(allowance > 0);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: type(uint48).max,
            period: period,
            allowance: allowance
        });

        vm.warp(start);
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissionManager.getCurrentPeriod(spendPermission);
        assertEq(usage.start, start);
        assertEq(usage.end, type(uint48).max);
        assertEq(usage.spend, 0);
    }
}
