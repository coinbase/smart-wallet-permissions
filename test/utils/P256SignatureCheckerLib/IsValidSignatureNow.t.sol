// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

contract IsValidSignatureNowTest is Test {
    function setUp() public {}

    function test_isValidSignatureNow_revert_InvalidSignerBytesLength() public {}

    function test_isValidSignatureNow_revert_InvalidEthereumAddressSigner() public {}

    function test_isValidSignatureNow_revert_abiDecodeError() public {}

    function test_isValidSignatureNow_success_EOA() public {}

    function test_isValidSignatureNow_success_smartContract() public {}

    function test_isValidSignatureNow_success_WebAuthn() public {}
}
