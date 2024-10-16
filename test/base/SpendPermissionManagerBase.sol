// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../src/SpendPermissionManager.sol";
import {MockSpendPermissionManager} from "../mocks/MockSpendPermissionManager.sol";
import {Base} from "./Base.sol";

import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {CoinbaseSmartWalletFactory} from "smart-wallet/CoinbaseSmartWalletFactory.sol";

contract SpendPermissionManagerBase is Base {
    address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockSpendPermissionManager mockSpendPermissionManager;
    CoinbaseSmartWalletFactory mockCoinbaseSmartWalletFactory;

    function _initializeSpendPermissionManager() internal {
        _initialize(); // Base
        mockSpendPermissionManager = new MockSpendPermissionManager();
        mockCoinbaseSmartWalletFactory = new CoinbaseSmartWalletFactory(address(account));
    }

    /**
     * @dev Helper function to create a SpendPermissionManager.SpendPermission struct with happy path defaults
     */
    function _createSpendPermission() internal view returns (SpendPermissionManager.SpendPermission memory) {
        return SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: permissionSigner,
            token: NATIVE_TOKEN,
            start: uint48(vm.getBlockTimestamp()),
            end: type(uint48).max,
            period: 604800,
            allowance: 1 ether
        });
    }

    function _signSpendPermission(
        SpendPermissionManager.SpendPermission memory spendPermission,
        uint256 ownerPk,
        uint256 ownerIndex
    ) internal view returns (bytes memory) {
        bytes32 spendPermissionHash = mockSpendPermissionManager.getHash(spendPermission);
        bytes32 replaySafeHash = account.replaySafeHash(spendPermissionHash);
        bytes memory signature = _sign(ownerPk, replaySafeHash);
        bytes memory wrappedSignature = _applySignatureWrapper(ownerIndex, signature);
        return wrappedSignature;
    }

    function _signSpendPermission6492(
        SpendPermissionManager.SpendPermission memory spendPermission,
        uint256 ownerPk,
        uint256 ownerIndex
    ) internal view returns (bytes memory) {
        bytes32 spendPermissionHash = mockSpendPermissionManager.getHash(spendPermission);
        bytes32 replaySafeHash = account.replaySafeHash(spendPermissionHash);
        bytes memory signature = _sign(ownerPk, replaySafeHash);
        bytes memory wrappedSignature = _applySignatureWrapper(ownerIndex, signature);

        // wrap inner sig in 6492 format ======================
        address factory = address(mockCoinbaseSmartWalletFactory);
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(vm.addr(ownerPk));
        bytes memory factoryCallData = abi.encodeWithSignature("createAccount(bytes[],uint256)", owners, 0);
        bytes memory eip6492Signature = abi.encode(factory, factoryCallData, wrappedSignature);
        eip6492Signature = abi.encodePacked(eip6492Signature, EIP6492_MAGIC_VALUE);
        return eip6492Signature;
    }

    function _safeAddUint48(uint48 a, uint48 b) internal pure returns (uint48 c) {
        bool overflow = uint256(a) + uint256(b) > type(uint48).max;
        return overflow ? type(uint48).max : a + b;
    }

    function _safeAddUint160(uint160 a, uint160 b) internal pure returns (uint160 c) {
        bool overflow = uint256(a) + uint256(b) > type(uint160).max;
        return overflow ? type(uint160).max : a + b;
    }
}
