// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManager} from "../../src/PermissionManager.sol";

contract PermissionManagerBase is Test {
    PermissionManager permissionManager;
    address owner = address(0xbabe);
    uint256 cosignerPrivateKey = 0xa11ce;
    address cosigner = vm.addr(cosignerPrivateKey);

    function _initializePermissionManager() internal {
        permissionManager = new PermissionManager(owner, cosigner);
    }
}
