// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract UseRecurringAllowanceTest is Test, SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }
    function test_useRecurringAllowance_success_noValue() public {}
    function test_useRecurringAllowance_revert_unauthorizedRecurringAllowance()
        public
    {}
    function test_useRecurringAllowance_revert_qithdrawValueOverflow() public {}
    function test_useRecurringAllowance_revert_exceededRecurringAllowance()
        public
    {}
    // TODO what are the various success logical cases?
    function test_userRecurringAllowance_success() public {}

}
