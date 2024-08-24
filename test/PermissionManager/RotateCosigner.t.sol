// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract RotateCosignerTest is Test, PermissionManagerBase {
    function setUp() public {}

    function test_setPendingCosigner_revert_Unauthorized() public {}

    function test_setPendingCosigner_success() public {}

    function test_rotateCosigner_revert_Unauthorized() public {}

    function test_rotateCosigner_revert_PendingCosignerIsZeroAddress() public {}

    function test_rotateCosigner_success() public {}
}
