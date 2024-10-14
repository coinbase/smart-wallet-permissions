// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MockERC20} from "solady/../test/utils/mocks/MockERC20.sol";

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";

contract WithdrawTest is SpendPermissionManagerBase {
    MockERC20 mockERC20 = new MockERC20("mockERC20", "TEST", 18);

    function setUp() public {
        _initializeSpendPermissionManager();
        vm.prank(owner);
        account.addOwnerAddress(address(mockSpendPermissionManager));
    }

    // non-permit, pre-approved overload of `spend`
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.prank(account);
        mockSpendPermissionManager.approve(spendPermission);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.InvalidSender.selector, permissionSigner));
        mockSpendPermissionManager.spend(spendPermission, recipient, spend);
        vm.stopPrank();
    }

    // permit-required overload of `spend`
    function test_withdraw_revert_unauthorizedSpendPermission(
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
        vm.startPrank(permissionSigner);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.UnauthorizedSpendPermission.selector));
        mockSpendPermissionManager.spend(spendPermission, recipient, spend);
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
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

        bytes memory signature = _signSpendPermission(spendPermission, ownerPk, 0);

        vm.warp(start);

        vm.startPrank(permissionSigner);
        mockSpendPermissionManager.permit(spendPermission, signature);
        mockSpendPermissionManager.spend(spendPermission, recipient, spend);

        assertEq(address(account).balance, allowance - spend);
        assertEq(recipient.balance, spend);
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissionManager.getCurrentPeriod(spendPermission);
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
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
        mockSpendPermissionManager.approve(spendPermission);
        vm.warp(start);

        assertEq(address(account).balance, allowance);
        assertEq(recipient.balance, 0);
        vm.prank(permissionSigner);
        mockSpendPermissionManager.spend(spendPermission, recipient, spend);
        assertEq(address(account).balance, allowance - spend);
        assertEq(recipient.balance, spend);
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissionManager.getCurrentPeriod(spendPermission);
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
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
        mockSpendPermissionManager.approve(spendPermission);
        vm.warp(start);

        assertEq(mockERC20.balanceOf(address(account)), allowance);
        assertEq(mockERC20.balanceOf(recipient), 0);
        vm.prank(permissionSigner);
        mockSpendPermissionManager.spend(spendPermission, recipient, spend);
        assertEq(mockERC20.balanceOf(address(account)), allowance - spend);
        assertEq(mockERC20.balanceOf(recipient), spend);
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissionManager.getCurrentPeriod(spendPermission);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }
}
