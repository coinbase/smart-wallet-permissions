// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Static} from "../../base/Static.sol";
import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "solady/../test/utils/mocks/MockERC20.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract WithdrawTest is Test, SpendPermissionsBase {
    MockERC20 token = new MockERC20("mockERC20", "TEST", 18);

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
    function test_withdraw_revert_unauthorizedRecurringAllowance() public {}

    // success when uninitialized but contains valid context with signature
    // success when already initialized (non-permit withdraw overload)
    // success emits event
    // success updates state? (how much of the functionality of useRecurringAllowance do we really need to re-test?)
    function test_withdraw_success_ether(
        address permissionSigner,
        address recipient,
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
        vm.prank(address(account));
        mockSpendPermissions.approve(recurringAllowance);
        vm.warp(start);

        vm.prank(permissionSigner);
        mockSpendPermissions.withdraw(recurringAllowance, recipient, spend);
    }

    function test_withdraw_success_ERC20() public {}
    // test balance changes on the account and recipient? (how do we set up and deploy a mock ERC20? for now can we just
    // mock _execute and have it succeed?)
    // test... transferFrom events?
}
