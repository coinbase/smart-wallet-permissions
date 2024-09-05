// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {Test, console2} from "forge-std/Test.sol";

import {UserOperation, UserOperationLib} from "../../../../src/utils/UserOperationLib.sol";

import {Base} from "../../../base/Base.sol";

contract GetUserOpHashTest is Test, Base {
    function setUp() public {}

    function test_getUserOpHash_eq_EntryPointGetUserOpHash() public {
        UserOperation memory userOp = _createUserOperation();

        vm.createSelectFork(BASE_SEPOLIA_RPC);
        assertEq(UserOperationLib.getUserOpHash(userOp), IEntryPoint(ENTRY_POINT_V06).getUserOpHash(userOp));
    }
}
