// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract ConstructorTest is Test, PermissionManagerBase {
    function setUp() public override {}

    function test_constructor_revert_NewOwnerIsZeroAddress() public {}

    function test_constructor_revert_PendingCosignerIsZeroAddress() public {}

    function test_constructor_success() public {}
}
