// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissions} from "../../src/SpendPermissions.sol";

contract MockSpendPermissions is SpendPermissions {
    function useRecurringAllowance(RecurringAllowance memory recurringAllowance, uint256 value) public {
        _useRecurringAllowance(recurringAllowance, value);
    }
}
