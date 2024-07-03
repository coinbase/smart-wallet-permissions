// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {PermissionManager} from "../src/PermissionManager.sol";

contract PermissionManagerTest is Test {

    PermissionManager sessionManager;

    function setUp() public {
        sessionManager = new PermissionManager();
    }

    function test_isValidSignature_reverts_invalidChainId() public {
        
    }
}