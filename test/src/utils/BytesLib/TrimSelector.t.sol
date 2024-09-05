// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {BytesLib} from "../../../../src/utils/BytesLib.sol";

contract TrimSelectorTest is Test {
    function setUp() public {}

    function test_trimSelector_eq_args(bytes4 selector, bytes memory data) public pure {
        bytes memory trimmed = BytesLib.trimSelector(abi.encodeWithSelector(selector, data));
        assertEq(trimmed, abi.encode(data));
    }

    function test_trimSelector_eq_calldataSlice(bytes calldata data) public pure {
        vm.assume(data.length > 4);
        bytes memory trimmed = BytesLib.trimSelector(data);
        assertEq(trimmed, data[4:]);
    }
}
