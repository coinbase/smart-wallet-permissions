// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";

contract PermitTest is SpendPermissionManagerBase {
    function setUp() public {
        _initializeSpendPermissionManager();
        vm.prank(owner);
        account.addOwnerAddress(address(mockSpendPermissionManager));
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

        bytes memory invalidSignature = _signSpendPermission(spendPermission, invalidPk, 0);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.UnauthorizedSpendPermission.selector));
        mockSpendPermissionManager.permit(spendPermission, invalidSignature);
    }

    function test_permit_success_isApproved(
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

        bytes memory signature = _signSpendPermission(spendPermission, ownerPk, 0);
        mockSpendPermissionManager.permit(spendPermission, signature);
        vm.assertTrue(mockSpendPermissionManager.isApproved(spendPermission));
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

        bytes memory signature = _signSpendPermission(spendPermission, ownerPk, 0);
        vm.expectEmit(address(mockSpendPermissionManager));
        emit SpendPermissionManager.SpendPermissionApproved({
            hash: mockSpendPermissionManager.getHash(spendPermission),
            account: address(account),
            spendPermission: spendPermission
        });
        mockSpendPermissionManager.permit(spendPermission, signature);
    }
}
