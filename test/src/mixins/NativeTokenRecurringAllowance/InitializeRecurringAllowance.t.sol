// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {NativeTokenRecurringAllowance} from "../../../../src/mixins/NativeTokenRecurringAllowance.sol";

import {NativeTokenRecurringAllowanceBase} from "../../../base/NativeTokenRecurringAllowanceBase.sol";

contract InitializeRecurringAllowanceTest is Test, NativeTokenRecurringAllowanceBase {
    function setUp() public {
        _initializeNativeTokenRecurringAllowance();
    }

    function test_initializeRecurringAllowance_revert_zeroRecurringAllowanceStart(
        address account,
        bytes32 permissionHash,
        uint48 period,
        uint160 allowance
    ) public {
        uint48 start = 0;
        vm.assume(period > 0);

        vm.expectRevert(abi.encodeWithSelector(NativeTokenRecurringAllowance.InvalidInitialization.selector));
        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );
    }

    function test_initializeRecurringAllowance_revert_zeroRecurringAllowancePeriod(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint160 allowance
    ) public {
        uint48 period = 0;
        vm.assume(start > 0);

        vm.expectRevert(abi.encodeWithSelector(NativeTokenRecurringAllowance.InvalidInitialization.selector));
        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );
    }

    function test_initializeRecurringAllowance_success_zeroAllowance(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period
    ) public {
        uint160 allowance = 0;
        vm.assume(start > 0);
        vm.assume(period > 0);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );
        NativeTokenRecurringAllowance.RecurringAllowance memory recurringAllowance =
            mockNativeTokenRecurringAllowance.getRecurringAllowance(account, permissionHash);
        assertEq(recurringAllowance.start, start);
        assertEq(recurringAllowance.period, period);
        assertEq(recurringAllowance.allowance, allowance);
    }

    function test_initializeRecurringAllowance_success_nonzeroAllowance(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );
        NativeTokenRecurringAllowance.RecurringAllowance memory recurringAllowance =
            mockNativeTokenRecurringAllowance.getRecurringAllowance(account, permissionHash);
        assertEq(recurringAllowance.start, start);
        assertEq(recurringAllowance.period, period);
        assertEq(recurringAllowance.allowance, allowance);
    }

    function test_initializeRecurringAllowance_success_replaySameValues(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );
        NativeTokenRecurringAllowance.RecurringAllowance memory recurringAllowance =
            mockNativeTokenRecurringAllowance.getRecurringAllowance(account, permissionHash);
        assertEq(recurringAllowance.start, start);
        assertEq(recurringAllowance.period, period);
        assertEq(recurringAllowance.allowance, allowance);

        // replay SAME values, no errors
        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );
        recurringAllowance = mockNativeTokenRecurringAllowance.getRecurringAllowance(account, permissionHash);
        assertEq(recurringAllowance.start, start);
        assertEq(recurringAllowance.period, period);
        assertEq(recurringAllowance.allowance, allowance);
    }

    function test_initializeRecurringAllowance_success_replayNewValues(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        uint48 newStart,
        uint48 newPeriod,
        uint160 newAllowance
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(newStart > 0 && start != newStart);
        vm.assume(newPeriod > 0 && period != newPeriod);
        vm.assume(newAllowance > 0 && allowance != newAllowance);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );
        NativeTokenRecurringAllowance.RecurringAllowance memory recurringAllowance =
            mockNativeTokenRecurringAllowance.getRecurringAllowance(account, permissionHash);
        assertEq(recurringAllowance.start, start);
        assertEq(recurringAllowance.period, period);
        assertEq(recurringAllowance.allowance, allowance);

        // replay NEW values, no errors
        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(newStart, newPeriod, newAllowance)
        );
        recurringAllowance = mockNativeTokenRecurringAllowance.getRecurringAllowance(account, permissionHash);
        // values unchanged
        assertEq(recurringAllowance.start, start);
        assertEq(recurringAllowance.period, period);
        assertEq(recurringAllowance.allowance, allowance);
    }
}
