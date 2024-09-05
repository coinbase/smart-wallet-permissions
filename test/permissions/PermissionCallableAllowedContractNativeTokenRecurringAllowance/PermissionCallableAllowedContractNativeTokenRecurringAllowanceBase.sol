// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {MagicSpend} from "magic-spend/MagicSpend.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {IPermissionCallable} from "../../../src/interfaces/IPermissionCallable.sol";
import {NativeTokenRecurringAllowance} from "../../../src/mixins/NativeTokenRecurringAllowance.sol";
import {PermissionCallableAllowedContractNativeTokenRecurringAllowance as PermissionContract} from
    "../../../src/permissions/PermissionCallableAllowedContractNativeTokenRecurringAllowance.sol";

import {PermissionManagerBase} from "../../PermissionManager/PermissionManagerBase.sol";
import {NativeTokenRecurringAllowanceBase} from
    "../../mixins/NativeTokenRecurringAllowance/NativeTokenRecurringAllowanceBase.sol";

contract PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase is
    PermissionManagerBase,
    NativeTokenRecurringAllowanceBase
{
    PermissionContract permissionContract;
    MagicSpend magicSpend;
    uint256 constant MAGIC_SPEND_MAX_WITHDRAW_DENOMINATOR = 20;

    function _initializePermissionContract() internal {
        _initializePermissionManager();

        magicSpend = new MagicSpend(owner, MAGIC_SPEND_MAX_WITHDRAW_DENOMINATOR);
        permissionContract = new PermissionContract(address(permissionManager), address(magicSpend));
    }

    function _createPermissionValues(uint48 start, uint48 period, uint160 allowance, address allowedContract)
        internal
        returns (PermissionContract.PermissionValues memory)
    {
        return PermissionContract.PermissionValues({
            recurringAllowance: _createRecurringAllowance(start, period, allowance),
            allowedContract: allowedContract
        });
    }

    function _createPermissionValues(uint160 allowance, address allowedContract)
        internal
        returns (PermissionContract.PermissionValues memory)
    {
        return PermissionContract.PermissionValues({
            recurringAllowance: _createRecurringAllowance({start: 1, period: type(uint24).max, allowance: allowance}),
            allowedContract: allowedContract
        });
    }

    function _createPermissionedCall(address target, uint256 value, bytes memory data)
        internal
        returns (CoinbaseSmartWallet.Call memory)
    {
        return CoinbaseSmartWallet.Call({
            target: target,
            value: value,
            data: abi.encodeWithSelector(IPermissionCallable.permissionedCall.selector, data)
        });
    }

    function _createUseRecurringAllowanceCall(address target, bytes32 permissionHash, uint256 spend)
        internal
        returns (CoinbaseSmartWallet.Call memory)
    {
        return CoinbaseSmartWallet.Call({
            target: target,
            value: 0,
            data: abi.encodeWithSelector(PermissionContract.useRecurringAllowance.selector, permissionHash, spend)
        });
    }

    function _createWithdrawCall(address target, address asset, uint256 amount)
        internal
        returns (CoinbaseSmartWallet.Call memory)
    {
        return CoinbaseSmartWallet.Call({
            target: target,
            value: 0,
            data: abi.encodeWithSelector(
                MagicSpend.withdraw.selector,
                MagicSpend.WithdrawRequest({signature: hex"", asset: asset, amount: amount, nonce: 0, expiry: 0})
            )
        });
    }
}
