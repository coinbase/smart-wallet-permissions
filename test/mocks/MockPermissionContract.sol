// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {IPermissionContract} from "../../src/interfaces/IPermissionContract.sol";

contract MockPermissionContract is IPermissionContract {
    bool public immutable alwaysRevert;

    constructor(bool arg) {
        alwaysRevert = arg;
    }

    function validatePermission(
        bytes32, /*permissionHash*/
        bytes calldata, /*permissionValues*/
        UserOperation calldata /*userOp*/
    ) external view {
        if (alwaysRevert) revert();
    }

    function initializePermission(address, /*account*/ bytes32, /*permissionHash*/ bytes calldata /*permissionValues*/ )
        external
    {}

    function validatePermissionedBatch(address, bytes32, bytes calldata, CoinbaseSmartWallet.Call[] calldata)
        external
    {}
}
