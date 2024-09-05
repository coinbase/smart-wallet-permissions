// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {NativeTokenRecurringAllowance} from "../../../src/mixins/NativeTokenRecurringAllowance.sol";

import {NativeTokenRecurringAllowanceBase} from "../../base/NativeTokenRecurringAllowanceBase.sol";

contract GetRecurringAllowanceUsageTest is Test, NativeTokenRecurringAllowanceBase {
    function setUp() public {
        _initializeNativeTokenRecurringAllowance();
    }

    function test_getRecurringAllowanceUsage_revert_uninitializedRecurringAllowance(
        address account,
        bytes32 permissionHash
    ) public {
        vm.expectRevert(abi.encodeWithSelector(NativeTokenRecurringAllowance.InvalidInitialization.selector));
        mockNativeTokenRecurringAllowance.getRecurringAllowanceUsage(account, permissionHash);
    }

    function test_getRecurringAllowanceUsage_revert_beforeRecurringAllowanceStart(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start - 1);
        vm.expectRevert(
            abi.encodeWithSelector(NativeTokenRecurringAllowance.BeforeRecurringAllowanceStart.selector, start)
        );
        mockNativeTokenRecurringAllowance.getRecurringAllowanceUsage(account, permissionHash);
    }

    function test_getRecurringAllowanceUsage_success_unused(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(allowance > 0);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);
        NativeTokenRecurringAllowance.CycleUsage memory usage =
            mockNativeTokenRecurringAllowance.getRecurringAllowanceUsage(account, permissionHash);
        assertEq(usage.start, start);
        assertEq(usage.end, start + period);
        assertEq(usage.spend, 0);
    }

    function test_getRecurringAllowanceUsage_success_startOfPeriod(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(allowance > 0);
        vm.assume(spend <= allowance);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
        NativeTokenRecurringAllowance.CycleUsage memory usage =
            mockNativeTokenRecurringAllowance.getRecurringAllowanceUsage(account, permissionHash);
        assertEq(usage.start, start);
        assertEq(usage.end, start + period);
        assertEq(usage.spend, spend);
    }

    function test_getRecurringAllowanceUsage_success_endOfPeriod(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(allowance > 0);
        vm.assume(spend <= allowance);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
        NativeTokenRecurringAllowance.CycleUsage memory usage =
            mockNativeTokenRecurringAllowance.getRecurringAllowanceUsage(account, permissionHash);

        vm.warp(start + period - 1);
        assertEq(usage.start, start);
        assertEq(usage.end, start + period);
        assertEq(usage.spend, spend);
    }

    function test_getRecurringAllowanceUsage_success_resetAfterPeriod(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(allowance > 0);
        vm.assume(spend <= allowance);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);

        vm.warp(start + period);
        NativeTokenRecurringAllowance.CycleUsage memory usage =
            mockNativeTokenRecurringAllowance.getRecurringAllowanceUsage(account, permissionHash);
        assertEq(usage.start, start + period);
        assertEq(usage.end, start + 2 * period);
        assertEq(usage.spend, 0);
    }
}
