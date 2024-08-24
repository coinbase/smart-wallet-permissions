// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract SetPermissionContractEnabledTest is Test, PermissionManagerBase {
    function setUp() public override {}

    function test_setPermissionContractEnabled_revert_Unauthorized() public {}

    function test_setPermissionContractEnabled_success() public {}
}
