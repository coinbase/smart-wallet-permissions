// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {Test, console2} from "forge-std/Test.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {Utils, WebAuthnInfo} from "webauthn-sol/../test/Utils.sol";
import {WebAuthn} from "webauthn-sol/WebAuthn.sol";

import {MockCoinbaseSmartWallet} from "../mocks/MockCoinbaseSmartWallet.sol";
import {MockPermissionSigner} from "../mocks/MockPermissionSigner.sol";

import {PermissionManager} from "../../src/PermissionManager.sol";
import {MockPermissionContract} from "../mocks/MockPermissionContract.sol";

contract PermissionManagerBase is Test {
    string public constant MAINNET_RPC_URL = "https://base.org";
    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;
    PermissionManager permissionManager;
    uint256 ownerPk = uint256(keccak256("owner"));
    address owner = vm.addr(ownerPk);
    uint256 cosignerPk = uint256(keccak256("cosigner"));
    address cosigner = vm.addr(cosignerPk);
    uint256 permmissionSignerPk = uint256(keccak256("permissionSigner"));
    address permissionSigner = vm.addr(permmissionSignerPk);
    uint256 p256PrivateKey = uint256(0x03d99692017473e2d631945a812607b23269d85721e0f370b8d3e7d29a874fd2);
    bytes p256PublicKey =
        hex"1c05286fe694493eae33312f2d2e0d0abeda8db76238b7a204be1fb87f54ce4228fef61ef4ac300f631657635c28e59bfb2fe71bce1634c81c65642042f6dc4d";
    MockPermissionSigner permissionSignerContract;
    MockCoinbaseSmartWallet account;
    MockPermissionContract successPermissionContract;
    MockPermissionContract failPermissionContract;

    function _initializePermissionManager() internal {
        permissionManager = new PermissionManager(owner, cosigner);
        permissionSignerContract = new MockPermissionSigner(permissionSigner);
        account = new MockCoinbaseSmartWallet();
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(owner);
        account.initialize(owners);
        successPermissionContract = new MockPermissionContract(false);
        failPermissionContract = new MockPermissionContract(true);
    }

    function _createPermission() internal returns (PermissionManager.Permission memory) {
        return PermissionManager.Permission({
            account: address(account),
            expiry: type(uint48).max,
            signer: abi.encode(permissionSigner),
            permissionContract: address(successPermissionContract),
            permissionValues: hex"",
            approval: hex""
        });
    }

    function _createUserOperation() internal returns (UserOperation memory) {
        return UserOperation({
            sender: address(account),
            nonce: 0,
            initCode: hex"",
            callData: hex"",
            callGasLimit: 0,
            verificationGasLimit: 0,
            preVerificationGas: 0,
            maxFeePerGas: 0,
            maxPriorityFeePerGas: 0,
            paymasterAndData: hex"",
            signature: hex""
        });
    }

    function _createExecuteBatchData(CoinbaseSmartWallet.Call[] memory calls) internal returns (bytes memory) {
        return abi.encodeWithSelector(CoinbaseSmartWallet.executeBatch.selector, calls);
    }

    function _createCall(address target, uint256 value, bytes memory data)
        internal
        returns (CoinbaseSmartWallet.Call memory)
    {
        return CoinbaseSmartWallet.Call(target, value, data);
    }

    function _createBeforeCallsData(PermissionManager.Permission memory permission, UserOperation memory userOp)
        internal
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            PermissionManager.beforeCalls.selector, permission, address(bytes20(userOp.paymasterAndData)), cosigner
        );
    }

    function _sign(uint256 pk, bytes32 hash) internal returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return abi.encodePacked(r, s, v);
    }

    function _signP256(uint256 pk, bytes32 hash) internal returns (bytes memory signature) {
        WebAuthnInfo memory webAuthn = Utils.getWebAuthnStruct(hash);
        (bytes32 r, bytes32 s) = vm.signP256(pk, webAuthn.messageHash);
        s = bytes32(Utils.normalizeS(uint256(s)));

        return abi.encode(
            WebAuthn.WebAuthnAuth({
                authenticatorData: webAuthn.authenticatorData,
                clientDataJSON: webAuthn.clientDataJSON,
                typeIndex: 1,
                challengeIndex: 23,
                r: uint256(r),
                s: uint256(s)
            })
        );
    }

    function _applySignatureWrapper(uint256 ownerIndex, bytes memory signatureData) internal returns (bytes memory) {
        return abi.encode(CoinbaseSmartWallet.SignatureWrapper(ownerIndex, signatureData));
    }

    function _signPermission(PermissionManager.Permission memory permission) internal returns (bytes memory) {
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        bytes32 replaySafeHash = account.replaySafeHash(permissionHash);
        bytes memory signature = _sign(ownerPk, replaySafeHash);
        bytes memory wrappedSignature = _applySignatureWrapper({ownerIndex: 0, signatureData: signature});
        return wrappedSignature;
    }
}
