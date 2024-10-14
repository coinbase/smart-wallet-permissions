// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../src/SpendPermissionManager.sol";

contract MockSpendPermissions is SpendPermissionManager {
    function useSpendPermission(SpendPermission memory spendPermission, uint256 value) public {
        _useSpendPermission(spendPermission, value);
    }
}
