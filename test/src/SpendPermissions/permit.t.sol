// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";

contract PermitTest is SpendPermissionManagerBase {
    function setUp() public {
        _initializeSpendPermissions();
        vm.prank(owner);
        account.addOwnerAddress(address(mockSpendPermissions));
    }

    function test_permit_revert_unauthorizedSpendPermission(
        uint128 invalidPk,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(invalidPk != 0);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        SpendPermissionManager.SignedPermission memory invalidSignedPermission =
            _createSignedPermission(spendPermission, invalidPk, 0);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.UnauthorizedSpendPermission.selector));
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        SpendPermissionManager.SignedPermission memory signedPermission =
            _createSignedPermission(spendPermission, ownerPk, 0);
        mockSpendPermissions.permit(signedPermission);
        vm.assertTrue(mockSpendPermissions.isAuthorized(spendPermission));
    }

    function test_permit_success_emitsEvent(
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        SpendPermissionManager.SignedPermission memory signedPermission =
            _createSignedPermission(spendPermission, ownerPk, 0);
        vm.expectEmit(address(mockSpendPermissions));
        emit SpendPermissionManager.SpendPermissionApproved({
            hash: mockSpendPermissions.getHash(spendPermission),
            account: address(account),
            spendPermission: spendPermission
        });
        mockSpendPermissions.permit(signedPermission);
    }
}
