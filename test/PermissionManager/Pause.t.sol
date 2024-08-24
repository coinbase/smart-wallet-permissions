// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract PauseTest is Test, PermissionManagerBase {
    function setUp() public override {}

    function test_pause_revert_Unauthorized() public {}

    function test_pause_revert_EnforcedPause() public {}

    function test_pause_success() public {}

    function test_unpause_revert_Unauthorized() public {}

    function test_unpause_revert_ExpectedPause() public {}

    function test_unpause_success() public {}
}
