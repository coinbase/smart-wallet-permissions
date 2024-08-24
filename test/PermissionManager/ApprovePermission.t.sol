// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract ApprovePermissionTest is Test, PermissionManagerBase {
    function setUp() public override {}

    function test_approvePermission_revert_InvalidPermissionApproval() public {}

    function test_approvePermission_success_senderIsAccount() public {}

    function test_approvePermission_success_validApprovalSignature() public {}

    function test_approvePermission_success_replay() public {}

    function test_approvePermission_success_batch() public {}
}
