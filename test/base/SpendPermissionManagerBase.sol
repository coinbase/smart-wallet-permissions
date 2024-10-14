// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../src/SpendPermissionManager.sol";
import {MockSpendPermissions} from "../mocks/MockSpendPermissions.sol";
import {Base} from "./Base.sol";

contract SpendPermissionManagerBase is Base {
    address constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockSpendPermissions mockSpendPermissions;

    function _initializeSpendPermissions() internal {
        _initialize(); // Base
        mockSpendPermissions = new MockSpendPermissions();
    }

    /**
     * @dev Helper function to create a SpendPermissionManager.SpendPermission struct with happy path defaults
     */
    function _createSpendPermission() internal view returns (SpendPermissionManager.SpendPermission memory) {
        return SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: permissionSigner,
            token: ETHER,
            start: uint48(vm.getBlockTimestamp()),
            end: type(uint48).max,
            period: 604800,
            allowance: 1 ether
        });
    }

    function _createSignedPermission(
        SpendPermissionManager.SpendPermission memory spendPermission,
        uint256 ownerPk,
        uint256 ownerIndex
    ) internal view returns (SpendPermissionManager.SignedPermission memory) {
        bytes32 spendPermissionHash = mockSpendPermissions.getHash(spendPermission);
        bytes32 replaySafeHash = account.replaySafeHash(spendPermissionHash);
        bytes memory signature = _sign(ownerPk, replaySafeHash);
        bytes memory wrappedSignature = _applySignatureWrapper(ownerIndex, signature);
        return SpendPermissionManager.SignedPermission({spendPermission: spendPermission, signature: wrappedSignature});
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
