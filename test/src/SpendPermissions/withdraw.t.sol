// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Static} from "../../base/Static.sol";

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "solady/../test/utils/mocks/MockERC20.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract WithdrawTest is Test, SpendPermissionsBase {
    MockERC20 mockERC20 = new MockERC20("mockERC20", "TEST", 18);

    function setUp() public {
        _initializeSpendPermissions();
        vm.prank(owner);
        account.addOwnerAddress(address(mockSpendPermissions));
    }

    // non-permit, pre-approved overload of `withdraw`
    function test_withdraw_revert_invalidSender(
        address sender,
        address account,
        address permissionSigner,
        address recipient,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(sender != permissionSigner);
        vm.assume(spend > 0);
        vm.assume(allowance > 0);
        vm.assume(allowance >= spend);
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.prank(account);
        mockSpendPermissions.approve(recurringAllowance);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissions.InvalidSender.selector, permissionSigner));
        mockSpendPermissions.withdraw(recurringAllowance, recipient, spend);
        vm.stopPrank();
    }

    // permit-required overload of `withdraw`
    function test_withdraw_revert_unauthorizedRecurringAllowance(
        uint128 invalidPk,
        address permissionSigner,
        address recipient,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(invalidPk != 0);
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(spend > 0);
        vm.assume(allowance > 0);
        vm.assume(allowance >= spend);
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        SpendPermissions.SignedPermission memory invalidSignedPermission =
            _createSignedPermission(recurringAllowance, invalidPk, 0);
        bytes memory context = abi.encode(invalidSignedPermission);

        vm.warp(start);

        vm.startPrank(permissionSigner);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissions.UnauthorizedRecurringAllowance.selector));
        mockSpendPermissions.withdraw(context, recipient, spend);
        vm.stopPrank();
    }

    function test_withdraw_success_ether_permit(
        address permissionSigner,
        address recipient,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(recipient != address(account)); // otherwise balance checks can fail
        assumePayable(recipient);
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(spend > 0);
        vm.assume(allowance > 0);
        vm.assume(allowance >= spend);
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.deal(address(account), allowance);
        vm.deal(recipient, 0);
        assertEq(address(account).balance, allowance);
        assertEq(recipient.balance, 0);

        SpendPermissions.SignedPermission memory signedPermission =
            _createSignedPermission(recurringAllowance, ownerPk, 0);
        bytes memory context = abi.encode(signedPermission);

        vm.warp(start);

        vm.prank(permissionSigner);
        mockSpendPermissions.withdraw(context, recipient, spend);

        assertEq(address(account).balance, allowance - spend);
        assertEq(recipient.balance, spend);
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }

    function test_withdraw_success_ether_alreadyInitialized(
        address permissionSigner,
        address recipient,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(recipient != address(account)); // otherwise balance checks can fail
        assumePayable(recipient);
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(spend > 0);
        vm.assume(allowance > 0);
        vm.assume(allowance >= spend);
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.deal(address(account), allowance);
        vm.deal(recipient, 0);
        vm.prank(address(account));
        mockSpendPermissions.approve(recurringAllowance);
        vm.warp(start);

        assertEq(address(account).balance, allowance);
        assertEq(recipient.balance, 0);
        vm.prank(permissionSigner);
        mockSpendPermissions.withdraw(recurringAllowance, recipient, spend);
        assertEq(address(account).balance, allowance - spend);
        assertEq(recipient.balance, spend);
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }

    function test_withdraw_success_ERC20(
        address permissionSigner,
        address recipient,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(recipient != address(account)); // otherwise balance checks can fail
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(spend > 0);
        vm.assume(allowance > 0);
        vm.assume(allowance >= spend);
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: address(mockERC20),
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        mockERC20.mint(address(account), allowance);
        vm.prank(address(account));
        mockSpendPermissions.approve(recurringAllowance);
        vm.warp(start);

        assertEq(mockERC20.balanceOf(address(account)), allowance);
        assertEq(mockERC20.balanceOf(recipient), 0);
        vm.prank(permissionSigner);
        mockSpendPermissions.withdraw(recurringAllowance, recipient, spend);
        assertEq(mockERC20.balanceOf(address(account)), allowance - spend);
        assertEq(mockERC20.balanceOf(recipient), spend);
        SpendPermissions.CycleUsage memory usage = mockSpendPermissions.getCurrentCycle(recurringAllowance);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }
}
