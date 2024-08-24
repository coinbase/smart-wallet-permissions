// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase as PermissionContractBase} from
    "./PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase.sol";

contract InitializePermissionTest is Test, PermissionContractBase {
    function setUp() public override {}

    function test_initializePermission_revert_decodingError() public {}

    function test_initializePermission_revert_InvalidInitializePermissionSender() public {}

    function test_initializePermission_success() public {}
}
