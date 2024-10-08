// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract WithdrawTest is Test, SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    // TODO best way to indicate the two different versions of `withdraw` in test names?
    function test_withdraw_revert_invalidSender() public {}
    function test_withdraw_revert_unauthorizedRecurringAllowance() public {}
    function test_withdraw_success_ether() public {}
    function test_withdraw_success_ERC20() public {}
}
