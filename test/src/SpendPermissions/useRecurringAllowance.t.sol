// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract UseRecurringAllowanceTest is Test, SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_useRecurringAllowance_revert_unauthorizedRecurringAllowance(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(spend > 0); // spend of 0 would be caught as unauthorized in permit version of `withdraw`, caller of
            // `useRecurringAllowance`

        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.expectRevert(SpendPermissions.UnauthorizedRecurringAllowance.selector);
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, spend);
    }

    // TODO test revert WithdrawValueOverflow after non-zero cumulative spend
    function test_useRecurringAllowance_revert_withdrawValueOverflow(
        address account,
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

        uint256 spend = uint256(type(uint160).max) + 1; // spend as a fuzz param with assumption spend > type(160).max
            // rejects too many inputs
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
        vm.warp(start);

        vm.expectRevert(abi.encodeWithSelector(SpendPermissions.WithdrawValueOverflow.selector, spend));
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, spend);
    }

    function test_useRecurringAllowance_revert_exceededRecurringAllowance(
        address account,
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
        vm.assume(spend > allowance);

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
        vm.warp(start);

        vm.expectRevert(abi.encodeWithSelector(SpendPermissions.ExceededRecurringAllowance.selector, spend, allowance));
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, spend);
    }

    function test_useRecurringAllowance_revert_exceededRecurringAllowance_accruedSpend(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 firstSpend,
        uint160 secondSpend
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(firstSpend < allowance);
        vm.assume(secondSpend > allowance - firstSpend);
        vm.assume(secondSpend < type(uint160).max - firstSpend);

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
        vm.warp(start);
        // make the first spend without using the full allowance
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, firstSpend);

        // exceed the allowance with the second spend
        vm.expectRevert(
            abi.encodeWithSelector(
                SpendPermissions.ExceededRecurringAllowance.selector,
                _safeAddUint160(firstSpend, secondSpend),
                allowance
            )
        );
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, secondSpend);
    }

    function test_useRecurringAllowance_success_noSpend() public {
        SpendPermissions.RecurringAllowance memory recurringAllowance = _createRecurringAllowance();
        vm.prank(recurringAllowance.account);
        mockSpendPermissions.approve(recurringAllowance);
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, 0);
    }

    function test_useRecurringAllowance_success_emitsEvent(
        address account,
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
        vm.assume(spend > 0);
        vm.assume(spend < allowance);

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
        vm.warp(start);
        vm.expectEmit(address(mockSpendPermissions));
        emit SpendPermissions.RecurringAllowanceWithdrawn({
            hash: mockSpendPermissions.getHash(recurringAllowance),
            account: account,
            token: ETHER,
            newUsage: SpendPermissions.CycleUsage({start: start, end: _safeAddUint48(start, period), spend: spend})
        });
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, spend);
    }

    function test_useRecurringAllowance_success_setsState(
        address account,
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
        vm.assume(spend > 0);
        vm.assume(spend < allowance);

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
        vm.warp(start);
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, spend);
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }

    function test_useRecurringAllowance_success_maxAllowance(
        address account,
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
        vm.warp(start);
        mockSpendPermissions.useRecurringAllowance(recurringAllowance, allowance); // spend full allowance
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, allowance);
    }

    function test_useRecurringAllowance_success_incrementalSpends(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint8 numberOfSpends
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(numberOfSpends > 1);
        vm.assume(allowance >= numberOfSpends);

        uint160 spend = allowance / numberOfSpends;

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
        vm.warp(start);
        uint256 expectedTotalSpend = 0;
        for (uint256 i; i < numberOfSpends; i++) {
            mockSpendPermissions.useRecurringAllowance(recurringAllowance, spend);
            expectedTotalSpend += spend;
            SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
            assertEq(usage.start, start);
            assertEq(usage.end, _safeAddUint48(start, period));
            assertEq(usage.spend, expectedTotalSpend);
        }
    }
}
