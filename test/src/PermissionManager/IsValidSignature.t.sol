// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {PermissionManager} from "../../../src/PermissionManager.sol";
import {CallErrors} from "../../../src/utils/CallErrors.sol";
import {SignatureCheckerLib} from "../../../src/utils/SignatureCheckerLib.sol";
import {UserOperation, UserOperationLib} from "../../../src/utils/UserOperationLib.sol";

import {PermissionManagerBase} from "../../base/PermissionManagerBase.sol";

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

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: hex"",
            userOpCosignature: hex""
        });

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidUserOperationSender.selector, sender));
        permissionManager.isValidSignature(UserOperationLib.getUserOpHash(userOp), abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_InvalidUserOperationHash(bytes32 hash) public {
        UserOperation memory userOp = _createUserOperation();
        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        vm.assume(hash != userOpHash);

        PermissionManager.Permission memory permission = _createPermission();
        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: hex"",
            userOpCosignature: hex""
        });

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidUserOperationHash.selector, userOpHash));
        permissionManager.isValidSignature(hash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_revokedPermission() public {
        PermissionManager.Permission memory permission = _createPermission();
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        UserOperation memory userOp = _createUserOperation();
        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: hex"",
            userOpCosignature: hex""
        });

        vm.prank(address(account));
        permissionManager.revokePermission(permissionHash);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.UnauthorizedPermission.selector));
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_notApproved() public {
        PermissionManager.Permission memory permission = _createPermission();
        permission.approval = hex""; // no approval signature

        UserOperation memory userOp = _createUserOperation();
        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: hex"",
            userOpCosignature: hex""
        });

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.UnauthorizedPermission.selector));
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_invalidUserOpSignature() public {
        PermissionManager.Permission memory permission = _createPermission();

        UserOperation memory userOp = _createUserOperation();
        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: hex"",
            userOpCosignature: hex""
        });

        vm.expectRevert();
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_invalidUserOpCosignature() public {
        PermissionManager.Permission memory permission = _createPermission();
        UserOperation memory userOp = _createUserOperation();

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = hex"";

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidSignature.selector));
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_invalidCosigner(uint128 userOpCosignerPk) public {
        vm.assume(userOpCosignerPk != 0);
        address userOpCosigner = vm.addr(userOpCosignerPk);
        vm.assume(userOpCosigner != cosigner);

        PermissionManager.Permission memory permission = _createPermission();
        UserOperation memory userOp = _createUserOperation();

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(userOpCosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidCosigner.selector, userOpCosigner));
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_notExecuteBatchCallData() public {
        PermissionManager.Permission memory permission = _createPermission();
        UserOperation memory userOp = _createUserOperation();

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        vm.expectRevert(abi.encodeWithSelector(CallErrors.SelectorNotAllowed.selector, bytes4(0)));
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_invalidExecuteBatchCallData() public {
        PermissionManager.Permission memory permission = _createPermission();
        UserOperation memory userOp = _createUserOperation();

        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, hex"");
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        vm.expectRevert(); // revert parsing `userOp.callData`
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_invalidBeforeCallsTarget(address target) public {
        vm.assume(target != address(permissionManager));

        PermissionManager.Permission memory permission = _createPermission();
        UserOperation memory userOp = _createUserOperation();

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        calls[0] = _createCall(target, 0, _createBeforeCallsData(permission));
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        // revert target not `address(permissionManager)`
        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidBeforeCallsCall.selector));
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_invalidBeforeCallsData(bytes memory beforeCallsData) public {
        PermissionManager.Permission memory permission = _createPermission();
        UserOperation memory userOp = _createUserOperation();

        vm.assume(keccak256(beforeCallsData) != keccak256(_createBeforeCallsData(permission)));

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        calls[0] = _createCall(address(permissionManager), 0, beforeCallsData);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        // revert data not valid
        vm.expectRevert(abi.encodeWithSelector(PermissionManager.InvalidBeforeCallsCall.selector));
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_accountReentrancy(bytes memory reentrancyData) public {
        PermissionManager.Permission memory permission = _createPermission();
        UserOperation memory userOp = _createUserOperation();

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](2);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission));
        calls[1] = _createCall(address(account), 0, reentrancyData);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        vm.expectRevert(abi.encodeWithSelector(CallErrors.TargetNotAllowed.selector, address(account)));
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_permissionManagerReentrancy(bytes memory reentrancyData) public {
        PermissionManager.Permission memory permission = _createPermission();
        UserOperation memory userOp = _createUserOperation();

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](2);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission));
        calls[1] = _createCall(address(permissionManager), 0, reentrancyData);
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        vm.expectRevert(abi.encodeWithSelector(CallErrors.TargetNotAllowed.selector, address(permissionManager)));
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_revert_validatePermission() public {
        PermissionManager.Permission memory permission = _createPermission();
        permission.permissionContract = address(failPermissionContract);
        UserOperation memory userOp = _createUserOperation();

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission));
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        vm.expectRevert();
        permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
    }

    function test_isValidSignature_success_permissionApprovalStorage() public {
        PermissionManager.Permission memory permission = _createPermission();
        UserOperation memory userOp = _createUserOperation();

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission));
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        vm.prank(address(account));
        permissionManager.approvePermission(permission);

        bytes4 magicValue = permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
        assertEq(magicValue, EIP1271_MAGIC_VALUE);
    }

    function test_isValidSignature_success_permissionApprovalSignature() public view {
        PermissionManager.Permission memory permission = _createPermission();

        permission.approval = _signPermission(permission);

        UserOperation memory userOp = _createUserOperation();

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission));
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        bytes4 magicValue = permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
        assertEq(magicValue, EIP1271_MAGIC_VALUE);
    }

    function test_isValidSignature_success_userOpSignatureEOA() public view {
        PermissionManager.Permission memory permission = _createPermission();

        permission.approval = _signPermission(permission);

        UserOperation memory userOp = _createUserOperation();

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission));
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        bytes4 magicValue = permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
        assertEq(magicValue, EIP1271_MAGIC_VALUE);
    }

    function test_isValidSignature_success_userOpSignatureContract() public view {
        PermissionManager.Permission memory permission = _createPermission();
        permission.signer = abi.encode(address(permissionSignerContract));

        permission.approval = _signPermission(permission);

        UserOperation memory userOp = _createUserOperation();

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission));
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _sign(permmissionSignerPk, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        bytes4 magicValue = permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
        assertEq(magicValue, EIP1271_MAGIC_VALUE);
    }

    function test_isValidSignature_success_userOpSignatureWebAuthn() public view {
        PermissionManager.Permission memory permission = _createPermission();
        permission.signer = p256PublicKey;

        permission.approval = _signPermission(permission);

        UserOperation memory userOp = _createUserOperation();

        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        calls[0] = _createCall(address(permissionManager), 0, _createBeforeCallsData(permission));
        bytes memory callData = abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
        userOp.callData = callData;

        bytes32 userOpHash = UserOperationLib.getUserOpHash(userOp);
        bytes memory userOpSignature = _signP256(p256PrivateKey, userOpHash);
        bytes memory userOpCosignature = _sign(cosignerPk, userOpHash);

        PermissionManager.PermissionedUserOperation memory pUserOp = PermissionManager.PermissionedUserOperation({
            permission: permission,
            userOp: userOp,
            userOpSignature: userOpSignature,
            userOpCosignature: userOpCosignature
        });

        bytes4 magicValue = permissionManager.isValidSignature(userOpHash, abi.encode(pUserOp));
        assertEq(magicValue, EIP1271_MAGIC_VALUE);
    }

    function test_isValidSignature_success_erc4337Compliance() public pure {
        revert("unimplemented");
    }
}
