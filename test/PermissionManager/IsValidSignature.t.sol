// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract IsValidSignatureTest is Test, PermissionManagerBase {
    function setUp() public override {}

    function test_isValidSignature_revert_decodeAuthData() public {}

    function test_isValidSignature_revert_InvalidUserOperationSender() public {}

    function test_isValidSignature_revert_InvalidUserOperationHash() public {}

    function test_isValidSignature_revert_RevokedPermission() public {}

    function test_isValidSignature_revert_InvalidPermissionApproval() public {}

    function test_isValidSignature_revert_InvalidSignature() public {}

    function test_isValidSignature_revert_SelectorNotAllowed() public {}

    function test_isValidSignature_revert_InvalidBeforeCallsCall() public {}

    function test_isValidSignature_revert_TargetNotAllowed() public {}

    function test_isValidSignature_revert_validatePermission() public {}

    function test_isValidSignature_success_permissionApprovalSignature() public {}

    function test_isValidSignature_success_permissionApprovalStorage() public {}

    function test_isValidSignature_success_userOpSignatureEOA() public {}

    function test_isValidSignature_success_userOpSignatureContract() public {}

    function test_isValidSignature_success_userOpSignatureWebAuthn() public {}

    function test_isValidSignature_success_replay() public {}

    function test_isValidSignature_success_erc4337Compliance() public {}
}
