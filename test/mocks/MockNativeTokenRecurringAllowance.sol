// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {NativeTokenRecurringAllowance} from "../../src/mixins/NativeTokenRecurringAllowance.sol";

contract MockNativeTokenRecurringAllowance is NativeTokenRecurringAllowance {
    function initializeRecurringAllowance(
        address account,
        bytes32 permissionHash,
        RecurringAllowance memory recurringAlowance
    ) public {
        _initializeRecurringAllowance(account, permissionHash, recurringAlowance);
    }

    function useRecurringAllowance(address account, bytes32 permissionHash, uint256 spend) public {
        _useRecurringAllowance(account, permissionHash, spend);
    }
}
