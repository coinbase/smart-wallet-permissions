// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {NativeTokenRecurringAllowance} from "../../../../src/mixins/NativeTokenRecurringAllowance.sol";

import {NativeTokenRecurringAllowanceBase} from "../../../base/NativeTokenRecurringAllowanceBase.sol";

contract UseRecurringAllowanceTest is Test, NativeTokenRecurringAllowanceBase {
    function setUp() public {
        _initializeNativeTokenRecurringAllowance();
    }

    function test_useRecurringAllowance_revert_invalidInitialization(
        address account,
        bytes32 permissionHash,
        uint256 spend
    ) public {
        vm.assume(spend > 0);

        vm.expectRevert(NativeTokenRecurringAllowance.InvalidInitialization.selector);
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
    }

    function test_useRecurringAllowance_revert_beforeRecurringAllowanceStart(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        uint256 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(spend > 0);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start - 1);
        vm.expectRevert(
            abi.encodeWithSelector(NativeTokenRecurringAllowance.BeforeRecurringAllowanceStart.selector, start)
        );
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
    }

    function test_useRecurringAllowance_revert_spendValueOverflow(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        uint256 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(spend > type(uint160).max);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);
        vm.expectRevert(abi.encodeWithSelector(NativeTokenRecurringAllowance.SpendValueOverflow.selector, spend));
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
    }

    function test_useRecurringAllowance_revert_exceededRecurringAllowance(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(allowance < type(uint160).max - 1);
        vm.assume(spend > allowance);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);
        vm.expectRevert(
            abi.encodeWithSelector(NativeTokenRecurringAllowance.ExceededRecurringAllowance.selector, spend, allowance)
        );
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
    }

    function test_useRecurringAllowance_revert_exceededRecurringAllowance_accruedSpend(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(allowance < type(uint160).max - 1);
        uint256 spend = allowance;

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);
        // first spend ok, within allowance
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
        // second spend not ok, exceeds allowance
        vm.expectRevert(
            abi.encodeWithSelector(
                NativeTokenRecurringAllowance.ExceededRecurringAllowance.selector, spend + 1, allowance
            )
        );
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, 1);
    }

    function test_useRecurringAllowance_success_noSpend(address account, bytes32 permissionHash) public {
        uint256 spend = 0;
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
    }

    function test_useRecurringAllowance_success(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(spend < allowance);

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
        NativeTokenRecurringAllowance.CycleUsage memory usage =
            mockNativeTokenRecurringAllowance.getRecurringAllowanceUsage(account, permissionHash);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAdd(start, period));
        assertEq(usage.spend, spend);
    }

    function test_useRecurringAllowance_success_maxAllowance(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        uint256 spend = allowance;

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);
        mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
        NativeTokenRecurringAllowance.CycleUsage memory usage =
            mockNativeTokenRecurringAllowance.getRecurringAllowanceUsage(account, permissionHash);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAdd(start, period));
        assertEq(usage.spend, spend);
    }

    function test_useRecurringAllowance_success_incrementalSpends(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        uint8 n
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(n > 1);
        vm.assume(allowance >= n);
        uint256 spend = allowance / n;

        mockNativeTokenRecurringAllowance.initializeRecurringAllowance(
            account, permissionHash, _createRecurringAllowance(start, period, allowance)
        );

        vm.warp(start);

        uint256 totalSpend = 0;
        for (uint256 i = 0; i < n; i++) {
            mockNativeTokenRecurringAllowance.useRecurringAllowance(account, permissionHash, spend);
            totalSpend += spend;
            NativeTokenRecurringAllowance.CycleUsage memory usage =
                mockNativeTokenRecurringAllowance.getRecurringAllowanceUsage(account, permissionHash);
            assertEq(usage.start, start);
            assertEq(usage.end, _safeAdd(start, period));
            assertEq(usage.spend, totalSpend);
        }
    }
}
