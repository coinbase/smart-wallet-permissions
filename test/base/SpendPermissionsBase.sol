// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../src/SpendPermissions.sol";
import {MockSpendPermissions} from "../mocks/MockSpendPermissions.sol";
import {Base} from "./Base.sol";

contract SpendPermissionsBase is Base {
    address constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockSpendPermissions mockSpendPermissions;

    function _initializeSpendPermissions() internal {
        _initialize(); // Base
        mockSpendPermissions = new MockSpendPermissions();
    }

    /**
     * @dev Helper function to create a SpendPermissions.RecurringAllowance struct with happy path defaults
     */
    function _createRecurringAllowance() internal view returns (SpendPermissions.RecurringAllowance memory) {
        return SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: uint48(vm.getBlockTimestamp()),
            end: type(uint48).max,
            period: 604800,
            allowance: 1 ether
        });
    }

    function _safeAddUint48(uint48 a, uint48 b) internal pure returns (uint48 c) {
        bool overflow = uint256(a) + uint256(b) > type(uint48).max;
        return overflow ? type(uint48).max : a + b;
    }

    function _safeAddUint160(uint160 a, uint160 b) internal pure returns (uint160 c) {
        bool overflow = uint256(a) + uint256(b) > type(uint160).max;
        return overflow ? type(uint160).max : a + b;
    }
}
