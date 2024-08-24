// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase as PermissionContractBase} from
    "./PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase.sol";

contract UseRecurringAllowanceTest is Test, PermissionContractBase {
    function setUp() public {}

    function test_useRecurringAllowance_success_noPaymaster() public {}

    function test_useRecurringAllowance_success_magicSpend() public {}

    function test_useRecurringAllowance_success_paymaster() public {}
}
