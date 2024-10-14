// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";
import {MockSpendPermissions} from "../../mocks/MockSpendPermissions.sol";

contract GetHashTest is SpendPermissionManagerBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_getHash_success(
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public view {
        SpendPermissionManager.SpendPermission memory recurringAllowance = SpendPermissionManager.SpendPermission({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        mockSpendPermissions.getHash(recurringAllowance);
    }

    function test_getHash_success_uniqueHashPerChain(
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance,
        uint64 chainId1,
        uint64 chainId2
    ) public {
        vm.assume(chainId1 != chainId2);
        vm.assume(chainId1 > 0);
        vm.assume(chainId2 > 0);
        SpendPermissionManager.SpendPermission memory recurringAllowance = SpendPermissionManager.SpendPermission({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.chainId(chainId1);
        bytes32 hash1 = mockSpendPermissions.getHash(recurringAllowance);
        vm.chainId(chainId2);
        bytes32 hash2 = mockSpendPermissions.getHash(recurringAllowance);
        assertNotEq(hash1, hash2);
    }

    function test_getHash_success_uniqueHashPerContract(
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        SpendPermissionManager.SpendPermission memory recurringAllowance = SpendPermissionManager.SpendPermission({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        MockSpendPermissions mockSpendPermissions1 = new MockSpendPermissions();
        MockSpendPermissions mockSpendPermissions2 = new MockSpendPermissions();
        bytes32 hash1 = mockSpendPermissions1.getHash(recurringAllowance);
        bytes32 hash2 = mockSpendPermissions2.getHash(recurringAllowance);
        assertNotEq(hash1, hash2);
    }
}
