// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

contract IsValidSignatureNowTest is Test {
    function setUp() public {}

    function test_isValidSignatureNow_revert_InvalidSignerBytesLength() public {
        revert("unimplemented");
    }

    function test_isValidSignatureNow_revert_InvalidEthereumAddressSigner() public {
        revert("unimplemented");
    }

    function test_isValidSignatureNow_revert_abiDecodeError() public {
        revert("unimplemented");
    }

    function test_isValidSignatureNow_success_EOA() public {
        revert("unimplemented");
    }

    function test_isValidSignatureNow_success_smartContract() public {
        revert("unimplemented");
    }

    function test_isValidSignatureNow_success_WebAuthn() public {
        revert("unimplemented");
    }
}
