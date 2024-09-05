// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {NativeTokenRecurringAllowance} from "../../../../src/mixins/NativeTokenRecurringAllowance.sol";

import {PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase as PermissionContractBase} from
    "../../../base/PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase.sol";

contract UseRecurringAllowanceTest is Test, PermissionContractBase {
    function setUp() public {
        _initializePermissionContract();
    }

    function test_useRecurringAllowance_revert_invalidInitialization(bytes32 permissionHash, uint256 spend) public {
        vm.assume(spend > 0);

        vm.expectRevert(NativeTokenRecurringAllowance.InvalidInitialization.selector);
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, spend);
    }

    function test_useRecurringAllowance_revert_beforeRecurringAllowanceStart(
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract,
        uint256 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(spend > 0);

        vm.prank(address(permissionManager));
        permissionContract.initializePermission(
            address(account),
            permissionHash,
            abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );
        NativeTokenRecurringAllowance.RecurringAllowance memory recurringAllowance =
            permissionContract.getRecurringAllowance(address(account), permissionHash);

        vm.warp(start - 1);
        vm.expectRevert(
            abi.encodeWithSelector(NativeTokenRecurringAllowance.BeforeRecurringAllowanceStart.selector, start)
        );
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, spend);
    }

    function test_useRecurringAllowance_revert_spendValueOverflow(
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract,
        uint256 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(spend > type(uint160).max);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);

        vm.prank(address(permissionManager));
        permissionContract.initializePermission(
            address(account),
            permissionHash,
            abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );

        vm.warp(start);
        vm.expectRevert(abi.encodeWithSelector(NativeTokenRecurringAllowance.SpendValueOverflow.selector, spend));
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, spend);
    }

    function test_useRecurringAllowance_revert_exceededRecurringAllowance(
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(allowance > 0);
        vm.assume(allowance < type(uint160).max - 1);
        vm.assume(spend > allowance);

        vm.prank(address(permissionManager));
        permissionContract.initializePermission(
            address(account),
            permissionHash,
            abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );

        vm.warp(start);
        vm.expectRevert(
            abi.encodeWithSelector(NativeTokenRecurringAllowance.ExceededRecurringAllowance.selector, spend, allowance)
        );
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, spend);
    }

    function test_useRecurringAllowance_revert_exceededRecurringAllowance_accruedSpend(
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(allowance > 0);
        vm.assume(allowance < type(uint160).max - 1);
        uint256 spend = allowance;

        vm.prank(address(permissionManager));
        permissionContract.initializePermission(
            address(account),
            permissionHash,
            abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );

        vm.warp(start);
        // first spend ok, within allowance
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, spend);
        // second spend not ok, exceeds allowance
        vm.expectRevert(
            abi.encodeWithSelector(
                NativeTokenRecurringAllowance.ExceededRecurringAllowance.selector, spend + 1, allowance
            )
        );
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, 1);
    }

    function test_useRecurringAllowance_success_noSpend(bytes32 permissionHash) public {
        uint256 spend = 0;
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, spend);
    }

    function test_useRecurringAllowance_success(
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(allowance > 0);
        vm.assume(spend < allowance);

        vm.prank(address(permissionManager));
        permissionContract.initializePermission(
            address(account),
            permissionHash,
            abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );

        vm.warp(start);
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, spend);
        NativeTokenRecurringAllowance.CycleUsage memory usage =
            permissionContract.getRecurringAllowanceUsage(address(account), permissionHash);
        assertEq(usage.start, start);
        assertEq(usage.end, start + period);
        assertEq(usage.spend, spend);
    }

    function test_useRecurringAllowance_success_maxAllowance(
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(allowance > 0);
        uint256 spend = allowance;

        vm.prank(address(permissionManager));
        permissionContract.initializePermission(
            address(account),
            permissionHash,
            abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );

        vm.warp(start);
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, spend);
        NativeTokenRecurringAllowance.CycleUsage memory usage =
            permissionContract.getRecurringAllowanceUsage(address(account), permissionHash);
        assertEq(usage.start, start);
        assertEq(usage.end, start + period);
        assertEq(usage.spend, spend);
    }

    function test_useRecurringAllowance_success_incrementalSpends(
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract,
        uint8 n
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(n > 1);
        vm.assume(allowance >= n);
        uint256 spend = allowance / n;

        vm.prank(address(permissionManager));
        permissionContract.initializePermission(
            address(account),
            permissionHash,
            abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );

        vm.warp(start);

        uint256 totalSpend = 0;
        for (uint256 i = 0; i < n; i++) {
            vm.prank(address(account));
            permissionContract.useRecurringAllowance(permissionHash, spend);
            totalSpend += spend;
            NativeTokenRecurringAllowance.CycleUsage memory usage =
                permissionContract.getRecurringAllowanceUsage(address(account), permissionHash);
            assertEq(usage.start, start);
            assertEq(usage.end, start + period);
            assertEq(usage.spend, totalSpend);
        }
    }

    // the unique and most important test is this one to make sure accounting of recurring allowances are independent
    // for different senders, even on the same permissionHash
    function test_useRecurringAllowance_success_perSenderAccounting(
        address otherSender,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);
        vm.assume(start < type(uint24).max);
        vm.assume(period < type(uint24).max);
        vm.assume(allowance > 0);
        vm.assume(spend < allowance);
        vm.assume(spend > 0);
        vm.assume(otherSender != address(account));

        vm.prank(address(permissionManager));
        permissionContract.initializePermission(
            address(account),
            permissionHash,
            abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );

        vm.warp(start);
        vm.prank(address(account));
        permissionContract.useRecurringAllowance(permissionHash, spend);
        NativeTokenRecurringAllowance.CycleUsage memory usage =
            permissionContract.getRecurringAllowanceUsage(address(account), permissionHash);
        assertEq(usage.start, start);
        assertEq(usage.end, start + period);
        assertEq(usage.spend, spend);

        // checking same permissionHash on other sender fails because hasn't been initialized
        vm.expectRevert(abi.encodeWithSelector(NativeTokenRecurringAllowance.InvalidInitialization.selector));
        usage = permissionContract.getRecurringAllowanceUsage(otherSender, permissionHash);

        vm.prank(address(permissionManager));
        permissionContract.initializePermission(
            otherSender, permissionHash, abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );

        vm.startPrank(otherSender);
        permissionContract.useRecurringAllowance(permissionHash, spend - 1);

        // original recurring allowance usage untouched
        usage = permissionContract.getRecurringAllowanceUsage(address(account), permissionHash);
        assertEq(usage.start, start);
        assertEq(usage.end, start + period);
        assertEq(usage.spend, spend);

        // new recurring allowance usage for other sender
        usage = permissionContract.getRecurringAllowanceUsage(otherSender, permissionHash);
        assertEq(usage.start, start);
        assertEq(usage.end, start + period);
        assertEq(usage.spend, spend - 1);
    }
}
