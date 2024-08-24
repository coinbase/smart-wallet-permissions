// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase as PermissionContractBase} from
    "./PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase.sol";

contract ValidatePermissionTest is Test, PermissionContractBase {
    function setUp() public {}

    function test_validatePermission_revert_decodeError() public {}

    function test_validatePermission_revert_TargetNotAllowed_permissionedCall() public {}

    function test_validatePermission_revert_TargetNotAllowed_withdraw() public {}

    function test_validatePermission_revert_InvalidWithdrawAsset_withdraw() public {}

    function test_validatePermission_revert_SelectorNotAllowed() public {}

    function test_validatePermission_revert_InvalidUseRecurringAllowanceCall() public {}

    function test_validatePermission_success_permissionedCall() public {}

    function test_validatePermission_success_withdraw() public {}

    function test_validatePermission_success_withdrawGasExcess() public {}

    function test_validatePermission_success_batchCalls() public {}
}
