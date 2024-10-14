// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";

contract UseSpendPermissionTest is SpendPermissionManagerBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_useSpendPermission_revert_unauthorizedSpendPermission(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 spend
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(spend > 0); // spend of 0 would be caught as unauthorized in permit version of `spend`, caller of
            // `useSpendPermission`

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.expectRevert(SpendPermissionManager.UnauthorizedSpendPermission.selector);
        mockSpendPermissions.useSpendPermission(spendPermission, spend);
    }

    function test_useSpendPermission_revert_withdrawValueOverflow(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);

        uint256 spend = uint256(type(uint160).max) + 1; // spend as a fuzz param with assumption spend > type(160).max
            // rejects too many inputs
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.prank(account);
        mockSpendPermissions.approve(spendPermission);
        vm.warp(start);

        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.WithdrawValueOverflow.selector, spend));
        mockSpendPermissions.useSpendPermission(spendPermission, spend);
    }

    function test_useSpendPermission_revert_exceededSpendPermission(
        address account,
        address permissionSigner,
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
        vm.assume(allowance > 0);
        vm.assume(spend > allowance);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.prank(account);
        mockSpendPermissions.approve(spendPermission);
        vm.warp(start);

        vm.expectRevert(
            abi.encodeWithSelector(SpendPermissionManager.ExceededSpendPermission.selector, spend, allowance)
        );
        mockSpendPermissions.useSpendPermission(spendPermission, spend);
    }

    function test_useSpendPermission_revert_exceededSpendPermission_accruedSpend(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint160 firstSpend,
        uint160 secondSpend
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(firstSpend < allowance);
        vm.assume(secondSpend > allowance - firstSpend);
        vm.assume(secondSpend < type(uint160).max - firstSpend);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.prank(account);
        mockSpendPermissions.approve(spendPermission);
        vm.warp(start);
        // make the first spend without using the full allowance
        mockSpendPermissions.useSpendPermission(spendPermission, firstSpend);

        // exceed the allowance with the second spend
        vm.expectRevert(
            abi.encodeWithSelector(
                SpendPermissionManager.ExceededSpendPermission.selector,
                _safeAddUint160(firstSpend, secondSpend),
                allowance
            )
        );
        mockSpendPermissions.useSpendPermission(spendPermission, secondSpend);
    }

    function test_useSpendPermission_success_noSpend() public {
        SpendPermissionManager.SpendPermission memory spendPermission = _createSpendPermission();
        vm.prank(spendPermission.account);
        mockSpendPermissions.approve(spendPermission);
        mockSpendPermissions.useSpendPermission(spendPermission, 0);
    }

    function test_useSpendPermission_success_emitsEvent(
        address account,
        address permissionSigner,
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
        vm.assume(allowance > 0);
        vm.assume(spend > 0);
        vm.assume(spend < allowance);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(account);
        mockSpendPermissions.approve(spendPermission);
        vm.warp(start);
        vm.expectEmit(address(mockSpendPermissions));
        emit SpendPermissionManager.SpendPermissionUsed({
            hash: mockSpendPermissions.getHash(spendPermission),
            account: account,
            token: ETHER,
            newUsage: SpendPermissionManager.PeriodUsage({start: start, end: _safeAddUint48(start, period), spend: spend})
        });
        mockSpendPermissions.useSpendPermission(spendPermission, spend);
    }

    function test_useSpendPermission_success_setsState(
        address account,
        address permissionSigner,
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
        vm.assume(allowance > 0);
        vm.assume(spend > 0);
        vm.assume(spend < allowance);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(account);
        mockSpendPermissions.approve(spendPermission);
        vm.warp(start);
        mockSpendPermissions.useSpendPermission(spendPermission, spend);
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissions.getCurrentPeriod(spendPermission);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, spend);
    }

    function test_useSpendPermission_success_maxAllowance(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(account);
        mockSpendPermissions.approve(spendPermission);
        vm.warp(start);
        mockSpendPermissions.useSpendPermission(spendPermission, allowance); // spend full allowance
        SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissions.getCurrentPeriod(spendPermission);
        assertEq(usage.start, start);
        assertEq(usage.end, _safeAddUint48(start, period));
        assertEq(usage.spend, allowance);
    }

    function test_useSpendPermission_success_incrementalSpends(
        address account,
        address permissionSigner,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint8 numberOfSpends
    ) public {
        vm.assume(start > 0);
        vm.assume(end > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(numberOfSpends > 1);
        vm.assume(allowance >= numberOfSpends);

        uint160 spend = allowance / numberOfSpends;

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: permissionSigner,
            token: ETHER,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        vm.prank(account);
        mockSpendPermissions.approve(spendPermission);
        vm.warp(start);
        uint256 expectedTotalSpend = 0;
        for (uint256 i; i < numberOfSpends; i++) {
            mockSpendPermissions.useSpendPermission(spendPermission, spend);
            expectedTotalSpend += spend;
            SpendPermissionManager.PeriodUsage memory usage = mockSpendPermissions.getCurrentPeriod(spendPermission);
            assertEq(usage.start, start);
            assertEq(usage.end, _safeAddUint48(start, period));
            assertEq(usage.spend, expectedTotalSpend);
        }
    }
}
