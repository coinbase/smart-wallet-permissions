// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";

contract IsAuthorizedTest is SpendPermissionManagerBase {
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(account);
        mockSpendPermissions.approve(spendPermission);
        vm.assertTrue(mockSpendPermissions.isAuthorized(spendPermission));
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.assertFalse(mockSpendPermissions.isAuthorized(spendPermission));
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.startPrank(account);

        mockSpendPermissions.approve(spendPermission);
        vm.assertTrue(mockSpendPermissions.isAuthorized(spendPermission));

        mockSpendPermissions.revoke(spendPermission);
        vm.assertFalse(mockSpendPermissions.isAuthorized(spendPermission));
        vm.stopPrank();
    }
}
