// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract GetCurrentCycleTest is Test, SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_getCurrentCycle_revert_beforeRecurringAllowanceStart() public {}
    function test_getCurrentCycle_revert_afterRecurringAllowanceEnd() public {}
    function test_getCurrentCycle_success_lastCycleStillActive() public {}
    function test_getCurrentCycle_success_determineCurrentCycle() public {}

}
