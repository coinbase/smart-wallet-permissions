// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract RevokePermissionTest is Test, PermissionManagerBase {
    function setUp() public {}

    function test_revokePermission_success() public {}

    function test_revokePermission_success_differentAccounts() public {}

    function test_revokePermission_success_replaySameAccount() public {}

    function test_revokePermission_success_batch() public {}
}
