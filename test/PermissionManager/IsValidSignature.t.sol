// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {UserOperation, UserOperationLib} from "../../src/utils/UserOperationLib.sol";

import {PermissionManager, PermissionManagerBase} from "./PermissionManagerBase.sol";

contract IsValidSignatureTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_isValidSignature_revert_decodePermissionedUserOp(bytes32 userOpHash) public {
        vm.expectRevert();
        permissionManager.isValidSignature(userOpHash, hex"");
    }

    function test_isValidSignature_revert_invalidUserOperationSender(address sender) public {
        PermissionManager.Permission memory permission = _createPermission();
        vm.assume(sender != permission.account);

        UserOperation memory userOp = _createUserOperation();
        userOp.sender = sender;

        PermissionManager.PermissionedUserOperation memory pUserOp = _createPermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: hex"",
            userOpCosignature: hex""
        });

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidUserOperationSender.selector, sender));
        permissionManager.isValidSignature(UserOperationLib.getUserOpHash(userOp), abi.encode(pUserOp));
    }

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
