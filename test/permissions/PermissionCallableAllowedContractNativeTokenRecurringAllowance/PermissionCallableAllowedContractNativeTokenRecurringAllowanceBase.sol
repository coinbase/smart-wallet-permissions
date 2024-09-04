// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {MagicSpend} from "magic-spend/MagicSpend.sol";

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
}
