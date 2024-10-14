// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";

contract RevokeTest is SpendPermissionManagerBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_revoke_revert_invalidSender(
        address sender,
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(sender != address(0));
        vm.assume(sender != account);
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
        assertTrue(mockSpendPermissions.isAuthorized(spendPermission));
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.InvalidSender.selector, account));
        mockSpendPermissions.revoke(spendPermission);
        vm.stopPrank();
    }

    function test_revoke_success_isNoLongerAuthorized(
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
        assertTrue(mockSpendPermissions.isAuthorized(spendPermission));
        mockSpendPermissions.revoke(spendPermission);
        assertFalse(mockSpendPermissions.isAuthorized(spendPermission));
    }

    function test_revoke_success_emitsEvent(
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
        assertTrue(mockSpendPermissions.isAuthorized(spendPermission));
        vm.expectEmit(address(mockSpendPermissions));
        emit SpendPermissionManager.SpendPermissionRevoked({
            hash: mockSpendPermissions.getHash(spendPermission),
            account: account,
            spendPermission: spendPermission
        });
        mockSpendPermissions.revoke(spendPermission);
    }
}
