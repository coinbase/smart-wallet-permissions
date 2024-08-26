// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract SetPaymasterEnabledTest is Test, PermissionManagerBase {
    function setUp() public {}

    function test_setPaymasterEnabled_revert_Unauthorized() public {}

    function test_setPaymasterEnabled_success() public {}
}
