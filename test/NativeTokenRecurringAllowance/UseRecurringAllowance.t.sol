// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

contract UseRecurringAllowanceTest is Test {
    function setUp() public {}

    function test_useRecurringAllowance_earlyReturn_noSpend() public {}

    function test_useRecurringAllowance_revert_ZeroRecurringAllowance() public {}

    function test_useRecurringAllowance_revert_BeforeRecurringAllowanceStart() public {}

    function test_useRecurringAllowance_revert_SpendValueOverflow() public {}

    function test_useRecurringAllowance_revert_ExceededRecurringAllowance() public {}

    function test_useRecurringAllowance_success() public {}
}
