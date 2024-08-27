// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPermissionContract} from "../../src/interfaces/IPermissionContract.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";

contract MockPermissionContract is IPermissionContract {
    bool alwaysRevert;

    constructor(bool arg) {
        alwaysRevert = arg;
    }

    function validatePermission(bytes32 permissionHash, bytes calldata permissionValues, UserOperation calldata userOp)
        external
        view
    {
        if (alwaysRevert) revert();
    }

    function initializePermission(address account, bytes32 permissionHash, bytes calldata permissionValues) external {}
}
