// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {MagicSpend} from "magic-spend/MagicSpend.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {PermissionManager} from "../../../../src/PermissionManager.sol";
import {IPermissionCallable} from "../../../../src/interfaces/IPermissionCallable.sol";
import {PermissionCallableAllowedContractNativeTokenRecurringAllowance as PermissionContract} from
    "../../../../src/permissions/PermissionCallableAllowedContractNativeTokenRecurringAllowance.sol";
import {CallErrors} from "../../../../src/utils/CallErrors.sol";
import {UserOperation} from "../../../../src/utils/UserOperationLib.sol";

import {PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase as PermissionContractBase} from
    "../../../base/PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase.sol";

contract ValidatePermissionTest is Test, PermissionContractBase {
    function setUp() public {
        _initializePermissionContract();
    }

    function test_validatePermission_revert_noPaymaster(bytes32 permissionHash, bytes memory permissionValues) public {
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(address(0));

        vm.expectRevert(PermissionContract.GasSponsorshipRequired.selector);
        permissionContract.validatePermission(permissionHash, permissionValues, userOp);
    }

    function test_validatePermission_revert_magicSpendPaymaster(bytes32 permissionHash, bytes memory permissionValues)
        public
    {
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(address(magicSpend));

        vm.expectRevert(PermissionContract.GasSponsorshipRequired.selector);
        permissionContract.validatePermission(permissionHash, permissionValues, userOp);
    }

    function test_validatePermission_revert_decodeError(
        bytes32 permissionHash,
        bytes memory permissionValues,
        address paymaster
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        vm.expectRevert();
        permissionContract.validatePermission(permissionHash, permissionValues, userOp);
    }

    function test_validatePermission_revert_InvalidCallLength(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        address target,
        bytes3 data,
        uint256 spend
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](3);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createCall(target, spend, abi.encodePacked(data));
        calls[2] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, spend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(CallErrors.InvalidCallLength.selector);
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_revert_permissionedCall_TargetNotAllowed(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        address target
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        vm.assume(target != allowedContract);
        uint256 spend = 0;

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](3);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createPermissionedCall(target, spend, hex"");
        calls[2] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, spend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(abi.encodeWithSelector(CallErrors.TargetNotAllowed.selector, target));
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_revert_withdraw_TargetNotAllowed(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        address target,
        address asset,
        uint256 amount
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        vm.assume(target != address(magicSpend));
        uint256 spend = 0;

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](3);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createWithdrawCall(target, asset, amount);
        calls[2] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, spend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(abi.encodeWithSelector(CallErrors.TargetNotAllowed.selector, target));
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_revert_InvalidWithdrawAsset_withdraw(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        address asset,
        uint256 amount
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        vm.assume(asset != address(0));
        uint256 spend = 0;

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](3);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createWithdrawCall(address(magicSpend), asset, amount);
        calls[2] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, spend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(abi.encodeWithSelector(PermissionContract.InvalidWithdrawAsset.selector, asset));
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_revert_SelectorNotAllowed(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        address target,
        uint256 value,
        bytes4 selector
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        vm.assume(selector != IPermissionCallable.permissionedCall.selector);
        vm.assume(selector != MagicSpend.withdraw.selector);
        uint256 spend = 0;

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](3);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createCall(target, value, abi.encode(selector));
        calls[2] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, spend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(abi.encodeWithSelector(CallErrors.SelectorNotAllowed.selector, selector));
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_revert_missingUseRecurringAllowanceCall(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        address target
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        vm.assume(target != allowedContract);

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(PermissionContract.InvalidUseRecurringAllowanceCall.selector);
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_revert_invalidUseRecurringAllowanceCallTarget(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        address target
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        vm.assume(target != address(permissionContract));

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](2);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createUseRecurringAllowanceCall(target, permissionHash, 0);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(PermissionContract.InvalidUseRecurringAllowanceCall.selector);
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_revert_invalidUseRecurringAllowanceCallData_permissionHash(
        bytes32 invalidPermissionHash,
        address paymaster,
        uint160 allowance,
        address allowedContract
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        uint256 spend = 0;

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);

        vm.assume(invalidPermissionHash != permissionHash);

        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](2);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createUseRecurringAllowanceCall(address(permissionContract), invalidPermissionHash, spend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(PermissionContract.InvalidUseRecurringAllowanceCall.selector);
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_revert_invalidUseRecurringAllowanceCallData_spendNoCalls(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        uint160 invalidSpend
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        vm.assume(invalidSpend != 0);

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](2);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, invalidSpend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(PermissionContract.InvalidUseRecurringAllowanceCall.selector);
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_revert_invalidUseRecurringAllowanceCallData_spendSomeCalls(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        uint160 spend,
        uint160 invalidSpend
    ) public {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        vm.assume(invalidSpend != spend);

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](3);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createPermissionedCall(allowedContract, spend, hex"");
        calls[2] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, invalidSpend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        vm.expectRevert(PermissionContract.InvalidUseRecurringAllowanceCall.selector);
        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_success_permissionedCall(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        uint160 spend
    ) public view {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](3);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createPermissionedCall(allowedContract, spend, hex"");
        calls[2] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, spend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_success_withdraw(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        uint256 withdrawAmount
    ) public view {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        address asset = address(0);
        uint256 spend = 0;

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](3);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createWithdrawCall(address(magicSpend), asset, withdrawAmount);
        calls[2] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, spend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_success_batchCalls(
        address paymaster,
        uint160 allowance,
        address allowedContract,
        uint160 totalSpend,
        uint256 withdrawAmount,
        uint8 n
    ) public view {
        vm.assume(paymaster != address(0));
        vm.assume(paymaster != address(magicSpend));
        vm.assume(n > 0);
        vm.assume(totalSpend > n);
        address withdrawAsset = address(0);

        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        userOp.paymasterAndData = abi.encodePacked(paymaster);

        uint256 callsLen = 4 + uint16(n); // beforeCalls + withdraw + (n + 1) * permissionedCall + useRecurringAllowance
        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](callsLen);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission, userOp));
        calls[1] = _createWithdrawCall(address(magicSpend), withdrawAsset, withdrawAmount);
        // add n permissionedCalls for a portion of totalSpend
        for (uint256 i = 0; i < n; i++) {
            uint160 spend = totalSpend / n;
            calls[2 + i] = _createPermissionedCall(allowedContract, spend, hex"");
        }
        // additional spend for remainder of totalSpend / n so sum is still totalSpend
        calls[callsLen - 2] = _createPermissionedCall(allowedContract, totalSpend % n, hex"");
        calls[callsLen - 1] = _createUseRecurringAllowanceCall(address(permissionContract), permissionHash, totalSpend);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        permissionContract.validatePermission(
            permissionHash, abi.encode(_createPermissionValues(allowance, allowedContract)), userOp
        );
    }

    function test_validatePermission_success_erc4337Compliance() public pure {
        revert("unimplemented");
    }
}
