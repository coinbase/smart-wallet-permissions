// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {BytesLib} from "../../../src/utils/BytesLib.sol";

contract EqTest is Test {
    function setUp() public {}

    function test_eq_true_sameInputs(bytes memory data) public {
        assertTrue(BytesLib.eq(data, data));
    }

    function test_eq_false_differentInputs(bytes memory a, bytes memory b) public {
        vm.assume(keccak256(a) != keccak256(b));
        assertTrue(!BytesLib.eq(a, b));
    }
}
