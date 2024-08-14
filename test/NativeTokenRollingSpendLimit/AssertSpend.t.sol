// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {NativeTokenRollingSpendLimitBase} from "./NativeTokenRollingSpendLimitBase.sol";

contract AssertSpendTest is Test, NativeTokenRollingSpendLimitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_assertSpend_noPaymasterGasSpend(
        bytes32 permissionHash,
        uint48 spendPeriodDuration,
        uint256 spendPeriodLimit,
        uint200 callsSpend,
        uint128 gasSpend
    ) public {
        vm.assume(spendPeriodDuration > 0);
        vm.assume(spendPeriodDuration < type(uint48).max - 1);
        vm.assume(callsSpend < spendPeriodLimit);
        vm.assume(gasSpend < spendPeriodLimit);

        vm.warp(uint256(spendPeriodDuration) + 1);

        vm.prank(address(smartWallet));
        nativeTokenRollingSpendLimitPermission.assertSpend(
            permissionHash, spendPeriodDuration, spendPeriodLimit, callsSpend, gasSpend, paymaster
        );
        vm.assertEq(
            callsSpend,
            nativeTokenRollingSpendLimitPermission.calculateRollingSpend(
                address(smartWallet), permissionHash, spendPeriodDuration
            )
        );
    }

    function test_assertSpend_addPaymasterGasSpend(
        bytes32 permissionHash,
        uint48 spendPeriodDuration,
        uint256 spendPeriodLimit,
        uint200 callsSpend,
        uint128 gasSpend
    ) public {
        vm.assume(spendPeriodDuration > 0);
        vm.assume(spendPeriodDuration < type(uint48).max - 1);
        vm.assume(uint256(callsSpend) + uint256(gasSpend) < spendPeriodLimit);

        vm.warp(uint256(spendPeriodDuration) + 1);

        vm.prank(owner);
        permissionManager.setShouldAddPaymasterGasToTotalSpend(paymaster, true);

        vm.prank(address(smartWallet));
        nativeTokenRollingSpendLimitPermission.assertSpend(
            permissionHash, spendPeriodDuration, spendPeriodLimit, callsSpend, gasSpend, paymaster
        );
        vm.assertEq(
            uint256(callsSpend) + uint256(gasSpend),
            nativeTokenRollingSpendLimitPermission.calculateRollingSpend(
                address(smartWallet), permissionHash, spendPeriodDuration
            )
        );
    }

    function test_assertSpend_addGasSpend(
        bytes32 permissionHash,
        uint48 spendPeriodDuration,
        uint256 spendPeriodLimit,
        uint200 callsSpend,
        uint128 gasSpend
    ) public {
        vm.assume(spendPeriodDuration > 0);
        vm.assume(spendPeriodDuration < type(uint48).max - 1);
        vm.assume(uint256(callsSpend) + uint256(gasSpend) < spendPeriodLimit);

        vm.warp(uint256(spendPeriodDuration) + 1);

        vm.prank(address(smartWallet));
        nativeTokenRollingSpendLimitPermission.assertSpend(
            permissionHash, spendPeriodDuration, spendPeriodLimit, callsSpend, gasSpend, address(0)
        );
        vm.assertEq(
            uint256(callsSpend) + uint256(gasSpend),
            nativeTokenRollingSpendLimitPermission.calculateRollingSpend(
                address(smartWallet), permissionHash, spendPeriodDuration
            )
        );
    }
}
