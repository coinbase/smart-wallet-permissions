// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissions} from "../../src/SpendPermissions.sol";
import {MockSpendPermissions} from "../mocks/MockSpendPermissions.sol";
import {Base} from "./Base.sol";

contract SpendPermissionsBase is Base {
    address constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockSpendPermissions mockSpendPermissions;

    function _initializeSpendPermissions() internal {
        _initialize(); // Base
        mockSpendPermissions = new MockSpendPermissions();
    }

    /**
     * @dev Helper function to create a SpendPermissions.RecurringAllowance struct with happy path defaults
     */
    function _createRecurringAllowance() internal view returns (SpendPermissions.RecurringAllowance memory) {
        return SpendPermissions.RecurringAllowance({
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
        SpendPermissions.RecurringAllowance memory recurringAllowance,
        uint256 ownerPk,
        uint256 ownerIndex
    ) internal view returns (SpendPermissions.SignedPermission memory) {
        bytes32 recurringAllowanceHash = mockSpendPermissions.getHash(recurringAllowance);
        bytes32 replaySafeHash = account.replaySafeHash(recurringAllowanceHash);
        bytes memory signature = _sign(ownerPk, replaySafeHash);
        bytes memory wrappedSignature = _applySignatureWrapper(ownerIndex, signature);
        return SpendPermissions.SignedPermission({recurringAllowance: recurringAllowance, signature: wrappedSignature});
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
