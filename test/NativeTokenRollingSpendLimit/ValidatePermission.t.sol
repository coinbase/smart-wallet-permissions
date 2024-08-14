// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {
    NativeTokenRollingSpendLimitPermission,
    UserOperation
} from "../../src/permissions/NativeTokenRollingSpendLimit/NativeTokenRollingSpendLimitPermission.sol";

import {MockAllowedContract} from "../mocks/MockAllowedContract.sol";
import {NativeTokenRollingSpendLimitBase} from "./NativeTokenRollingSpendLimitBase.sol";

contract ValidatePermissionTest is Test, NativeTokenRollingSpendLimitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_validatePermission(
        bytes32 permissionHash,
        uint256 spendPeriodDuration,
        uint256 spendPeriodLimit,
        uint256 callsSpend
    ) public {
        vm.assume(callsSpend < spendPeriodLimit);
        vm.deal(address(smartWallet), callsSpend);

        MockAllowedContract allowedContract = new MockAllowedContract();

        // prepare permissionFields
        bytes memory permissionFields = abi.encode(spendPeriodDuration, spendPeriodLimit, address(allowedContract));

        // prepare calls
        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](3);

        // TODO replace with PermissionManager.checkBeforeCalls
        calls[0] = CoinbaseSmartWallet.Call(address(0), 0, bytes(""));

        // call allowed contract
        calls[1] = CoinbaseSmartWallet.Call(
            address(allowedContract), callsSpend, allowedContract.getMockPermissionedCallData()
        );

        // prepare assertSpend data
        bytes memory assertSpendData = abi.encodeWithSelector(
            NativeTokenRollingSpendLimitPermission.assertSpend.selector,
            permissionHash,
            spendPeriodDuration,
            spendPeriodLimit,
            callsSpend,
            0, // gasSpend
            paymaster // paymaster
        );
        // call assertSpend
        calls[2] = CoinbaseSmartWallet.Call(address(nativeTokenRollingSpendLimitPermission), 0, assertSpendData);

        // prepare executeBatch data
        bytes memory executeBatchData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);

        // build userOp
        UserOperation memory userOp = UserOperation(
            address(smartWallet), // address sender
            0, // uint256 nonce
            bytes(""), // bytes initCode
            executeBatchData, // bytes callData
            0, // uint256 callGasLimit
            0, // uint256 verificationGasLimit
            0, // uint256 preVerificationGas
            0, // uint256 maxFeePerGas
            0, // uint256 maxPriorityFeePerGas
            abi.encodePacked(paymaster), // bytes paymasterAndData
            bytes("") // bytes signature
        );

        // validate permission
        nativeTokenRollingSpendLimitPermission.validatePermission(permissionHash, permissionFields, userOp);
    }

    function test_assertSpend(
        bytes32 permissionHash,
        uint256 spendPeriodDuration,
        uint256 spendPeriodLimit,
        uint200 callsSpend,
        uint128 gasSpend
    ) public {
        vm.assume(callsSpend < spendPeriodLimit);
        vm.assume(gasSpend < spendPeriodLimit);
        vm.deal(address(smartWallet), callsSpend);

        vm.prank(address(smartWallet));
        nativeTokenRollingSpendLimitPermission.assertSpend(
            permissionHash, spendPeriodDuration, spendPeriodLimit, callsSpend, gasSpend, paymaster
        );
    }
}
