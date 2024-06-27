// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {SessionManager} from "../src/SessionManager.sol";
import {MockSuccessPermission, MockFailPermission} from "./TestUtils.sol";

contract SessionManagerTest is Test {

    SessionManager sessionManager;
    MockSuccessPermission successPermission;
    MockFailPermission failPermission;

    function setUp() public {
        sessionManager = new SessionManager();
        successPermission = new MockSuccessPermission();
        failPermission = new MockFailPermission();
    }

    function test_isValidSignature_reverts_invalidChainId() public {
        
    }
}