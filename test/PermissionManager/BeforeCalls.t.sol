// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract BeforeCallsTest is Test, PermissionManagerBase {
    function setUp() public {}

    function test_beforeCalls_revert_EnforcedPause() public {}

    function test_beforeCalls_revert_ExpiredPermission() public {}

    function test_beforeCalls_revert_DisabledPermissionContract() public {}

    function test_beforeCalls_revert_DisabledPaymaster() public {}

    function test_beforeCalls_revert_InvalidCosigner() public {}

    function test_beforeCalls_revert_InvalidPermissionApproval() public {}

    function test_beforeCalls_success_senderIsAccount() public {}

    function test_beforeCalls_success_validApprovalSignature() public {}

    function test_beforeCalls_success_noPaymaster() public {}

    function test_beforeCalls_success_enabledPaymaster() public {}

    function test_beforeCalls_success_cosigner() public {}

    function test_beforeCalls_success_pendingCosigner() public {}

    function test_beforeCalls_success_replay() public {}

    function test_beforeCalls_success_batch() public {}
}
