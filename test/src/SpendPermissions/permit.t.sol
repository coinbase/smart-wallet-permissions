// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract PermitTest is SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
        vm.prank(owner);
        account.addOwnerAddress(address(mockSpendPermissions));
    }

    function test_permit_revert_unauthorizedRecurringAllowance(
        uint128 invalidPk,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(invalidPk != 0);

        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        SpendPermissions.SignedPermission memory invalidSignedPermission =
            _createSignedPermission(recurringAllowance, invalidPk, 0);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissions.UnauthorizedRecurringAllowance.selector));
        mockSpendPermissions.permit(invalidSignedPermission);
    }

    function test_permit_success_isAuthorized(
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        SpendPermissions.SignedPermission memory signedPermission =
            _createSignedPermission(recurringAllowance, ownerPk, 0);
        mockSpendPermissions.permit(signedPermission);
        vm.assertTrue(mockSpendPermissions.isAuthorized(recurringAllowance));
    }

    function test_permit_success_emitsEvent(
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissions.RecurringAllowance memory recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        SpendPermissions.SignedPermission memory signedPermission =
            _createSignedPermission(recurringAllowance, ownerPk, 0);
        vm.expectEmit(address(mockSpendPermissions));
        emit SpendPermissions.RecurringAllowanceApproved({
            hash: mockSpendPermissions.getHash(recurringAllowance),
            account: address(account),
            recurringAllowance: recurringAllowance
        });
        mockSpendPermissions.permit(signedPermission);
    }
}
