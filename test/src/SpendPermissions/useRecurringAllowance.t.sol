// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract UseRecurringAllowanceTest is Test, SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_useRecurringAllowance_revert_unauthorizedRecurringAllowance() public {}
    function test_useRecurringAllowance_revert_withdrawValueOverflow() public {}
    function test_useRecurringAllowance_revert_exceededRecurringAllowance() public {}
    function test_useRecurringAllowance_revert_exceededRecurringAllowance_accruedSpend() public {}
    function test_useRecurringAllowance_success_noSpend() public {}
    function test_useRecurringAllowance_success_emitsEvent() public {}
    function test_useRecurringAllowance_success_setsState() public {}
    function test_useRecurringAllowance_success_maxAllowance_ether() public {}
    function test_useRecurringAllowance_success_maxAllowance_token() public {}
    function test_useRecurringAllowance_success_incrementalSpends_ether() public {}
    function test_useRecurringAllowance_success_incrementalSpends_token() public {}
}
