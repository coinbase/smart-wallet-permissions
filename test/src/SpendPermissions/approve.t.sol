// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract ApproveTest is Test, SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }

    function test_approve_revert_invalidSender() public {}
    function test_approve_success() public {}
}
