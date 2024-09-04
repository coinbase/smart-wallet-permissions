// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {Test, console2} from "forge-std/Test.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {MockCoinbaseSmartWallet} from "../mocks/MockCoinbaseSmartWallet.sol";

import {PermissionManager} from "../../src/PermissionManager.sol";
import {MockPermissionContract} from "../mocks/MockPermissionContract.sol";

contract PermissionManagerBase is Test {
    string public constant MAINNET_RPC_URL = "https://base.org";
    PermissionManager permissionManager;
    uint256 ownerPk = uint256(keccak256("owner"));
    address owner = vm.addr(ownerPk);
    uint256 cosignerPk = uint256(keccak256("cosigner"));
    address cosigner = vm.addr(cosignerPk);
    uint256 permmissionSignerPk = uint256(keccak256("permissionSigner"));
    address permissionSigner = vm.addr(permmissionSignerPk);
    MockCoinbaseSmartWallet account;
    MockPermissionContract successPermissionContract;
    MockPermissionContract failPermissionContract;

    function _initializePermissionManager() internal {
        permissionManager = new PermissionManager(owner, cosigner);
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
}
