// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract IsAuthorizedTest is SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_isAuthorized_true(
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(account);
        mockSpendPermissions.approve(recurringAllowance);
        vm.assertTrue(mockSpendPermissions.isAuthorized(recurringAllowance));
    }

    function test_isAuthorized_false_uninitialized(
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public view {
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.assertFalse(mockSpendPermissions.isAuthorized(recurringAllowance));
    }

    function test_isAuthorized_false_wasRevoked(
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.startPrank(account);

        mockSpendPermissions.approve(recurringAllowance);
        vm.assertTrue(mockSpendPermissions.isAuthorized(recurringAllowance));

        mockSpendPermissions.revoke(recurringAllowance);
        vm.assertFalse(mockSpendPermissions.isAuthorized(recurringAllowance));
        vm.stopPrank();
    }
}
