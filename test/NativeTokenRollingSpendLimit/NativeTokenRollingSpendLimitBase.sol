// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {NativeTokenRollingSpendLimitPermission} from
    "../../src/permissions/NativeTokenRollingSpendLimit/NativeTokenRollingSpendLimitPermission.sol";
import {PermissionManagerBase} from "../PermissionManager/PermissionManagerBase.sol";

contract NativeTokenRollingSpendLimitBase is PermissionManagerBase {
    NativeTokenRollingSpendLimitPermission public nativeTokenRollingSpendLimitPermission;

    function setUp() public virtual override {
        super.setUp();

        nativeTokenRollingSpendLimitPermission = new NativeTokenRollingSpendLimitPermission(address(permissionManager));
    }
}
