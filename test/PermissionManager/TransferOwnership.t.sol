// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract OwnershipTest is Test, PermissionManagerBase {
    function setUp() public {}

    function test_renounceOwnership_revert_CannotRenounceOwnership() public {}

    function test_renounceOwnership_revert_Unauthorized() public {}

    // sanity checks that Solady's Ownable enables ownership transfers

    function test_transferOwnership_revert_Unauthorized() public {}

    function test_transferOwnership_success() public {}

    function test_completeOwnershipHandover_revert_Unauthorized() public {}

    function test_completeOwnershipHandover_revert_NoHandoverRequest() public {}

    function test_completeOwnershipHandover_success() public {}
}
