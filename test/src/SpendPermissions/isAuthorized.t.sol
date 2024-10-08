// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {SpendPermissionsBase} from "../../base/SpendPermissionsBase.sol";

contract IsAuthorizedTest is Test, SpendPermissionsBase {
    function setUp() public {
        _initializeSpendPermissions();
    }
    function test_isAuthorized_success_true() public {}
    function test_isAuthorized_success_false() public {}
}
