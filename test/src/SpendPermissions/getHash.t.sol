// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";
import {MockSpendPermissionManager} from "../../mocks/MockSpendPermissionManager.sol";

contract GetHashTest is SpendPermissionManagerBase {
    function setUp() public {
        _initializeSpendPermissionManager();
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        MockSpendPermissionManager.getHash(spendPermission);
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        vm.chainId(chainId1);
        bytes32 hash1 = MockSpendPermissionManager.getHash(spendPermission);
        vm.chainId(chainId2);
        bytes32 hash2 = MockSpendPermissionManager.getHash(spendPermission);
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
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: account,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        MockSpendPermissionManager MockSpendPermissionManager1 = new MockSpendPermissionManager();
        MockSpendPermissionManager MockSpendPermissionManager2 = new MockSpendPermissionManager();
        bytes32 hash1 = MockSpendPermissionManager1.getHash(spendPermission);
        bytes32 hash2 = MockSpendPermissionManager2.getHash(spendPermission);
        assertNotEq(hash1, hash2);
    }
}
