// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../src/SpendPermissionManager.sol";

contract MockSpendPermissions is SpendPermissionManager {
    function useRecurringAllowance(SpendPermission memory recurringAllowance, uint256 value) public {
        _useRecurringAllowance(recurringAllowance, value);
    }
}
