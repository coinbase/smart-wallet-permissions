// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../src/SpendPermissions.sol";

import {MockSpendPermissions} from "../mocks/MockSpendPermissions.sol";

contract SpendPermissionsBase {
    MockSpendPermissions mockSpendPermissions;

    function _initializeSpendPermissions() internal {
        mockSpendPermissions = new MockSpendPermissions();
    }

    function _createRecurringAllowance(
        address account,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) internal pure returns (SpendPermissions.RecurringAllowance memory) {
        return SpendPermissions.RecurringAllowance(account, spender, token, start, end, period, allowance);
    }

    // we'll keep this around until we know we do or don't need it
    function _safeAdd(uint48 a, uint48 b) internal pure returns (uint48 c) {
        bool overflow = uint256(a) + uint256(b) > type(uint48).max;
        return overflow ? type(uint48).max : a + b;
    }
}
