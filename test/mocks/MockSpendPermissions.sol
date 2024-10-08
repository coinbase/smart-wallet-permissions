// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissions} from "../../src/SpendPermissions.sol";

contract MockSpendPermissions is SpendPermissions {

    // TODO: what other internal functions should be exposed?
    
    // function initializeRecurringAllowance(
    //     address account,
    //     bytes32 permissionHash,
    //     RecurringAllowance memory recurringAlowance
    // ) public {
    //     _initializeRecurringAllowance(account, permissionHash, recurringAlowance);
    // }

    function useRecurringAllowance(RecurringAllowance memory recurringAllowance, uint256 value) public {
        _useRecurringAllowance(recurringAllowance, value);
    }
}