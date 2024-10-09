// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";
import {SpendPermissionsPaymaster} from "../../../src/SpendPermissionsPaymaster.sol";

import {Base} from "../../base/Base.sol";
import {Static} from "../../base/Static.sol";

contract DebugTest is Test, Base {
    address constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    SpendPermissionsPaymaster spendPermissions;

    function setUp() public {
        _initialize();
        vm.etch(ENTRY_POINT_V06, Static.ENTRY_POINT_V06_BYTES);

        spendPermissions = new SpendPermissionsPaymaster(owner);

        vm.prank(owner);
        account.addOwnerAddress(address(spendPermissions));
    }

    function test_validatePaymasterUserOp_success(uint160 allowance, uint160 maxGasCost) public {
        vm.assume(maxGasCost > 1e6);
        vm.assume(maxGasCost < type(uint112).max);
        vm.assume(allowance > maxGasCost);

        SpendPermissions.RecurringAllowance memory recurringAllowance = _createRecurringAllowance();
        recurringAllowance.allowance = allowance;

        UserOperation memory userOp = _createUserOperation();
        userOp.sender = recurringAllowance.spender;
        userOp.callGasLimit = 1;
        userOp.verificationGasLimit = 1;
        userOp.preVerificationGas = 1;
        userOp.maxFeePerGas = 1;
        userOp.maxPriorityFeePerGas = 1;

        bytes32 hash = spendPermissions.getHash(recurringAllowance);
        bytes32 replaySafeHash = account.replaySafeHash(hash);
        bytes memory signature = _applySignatureWrapper(0, _sign(ownerPk, replaySafeHash));

        vm.assertEq(account.isValidSignature(hash, signature), IERC1271.isValidSignature.selector);

        SpendPermissions.SignedPermission memory signedPermission =
            SpendPermissions.SignedPermission(recurringAllowance, signature);
        bytes memory paymasterData = abi.encode(signedPermission, allowance);

        userOp.paymasterAndData = abi.encodePacked(address(spendPermissions), paymasterData);

        vm.deal(recurringAllowance.account, allowance);
        vm.prank(ENTRY_POINT_V06);
        (bytes memory postOpContext,) = spendPermissions.validatePaymasterUserOp(userOp, bytes32(0), maxGasCost);

        vm.assertEq(ENTRY_POINT_V06.balance, maxGasCost);
        vm.assertEq(address(spendPermissions).balance, allowance - maxGasCost);
        vm.assertEq(recurringAllowance.spender.balance, 0);

        vm.prank(ENTRY_POINT_V06);
        spendPermissions.postOp(IPaymaster.PostOpMode.opSucceeded, postOpContext, maxGasCost - 1);

        vm.assertEq(recurringAllowance.spender.balance, allowance - maxGasCost + 1);
    }

    function test_withdraw_success(uint160 allowance) public {
        vm.assume(allowance > 0);

        SpendPermissions.RecurringAllowance memory recurringAllowance = _createRecurringAllowance();
        recurringAllowance.allowance = allowance;

        bytes32 hash = spendPermissions.getHash(recurringAllowance);
        bytes32 replaySafeHash = account.replaySafeHash(hash);
        bytes memory signature = _applySignatureWrapper(0, _sign(ownerPk, replaySafeHash));

        vm.assertEq(account.isValidSignature(hash, signature), IERC1271.isValidSignature.selector);

        SpendPermissions.SignedPermission memory signedPermission =
            SpendPermissions.SignedPermission(recurringAllowance, signature);
        spendPermissions.permit(signedPermission);

        vm.assertTrue(spendPermissions.isAuthorized(recurringAllowance));

        vm.deal(recurringAllowance.account, allowance);
        vm.prank(recurringAllowance.spender);
        spendPermissions.withdraw(recurringAllowance, recurringAllowance.spender, 1);

        vm.assertEq(recurringAllowance.spender.balance, 1);
    }

    function _createRecurringAllowance()
        internal
        view
        returns (SpendPermissions.RecurringAllowance memory recurringAllowance)
    {
        recurringAllowance = SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: owner,
            token: ETHER,
            start: 0,
            end: type(uint48).max,
            period: type(uint48).max,
            allowance: 0
        });
    }
}
