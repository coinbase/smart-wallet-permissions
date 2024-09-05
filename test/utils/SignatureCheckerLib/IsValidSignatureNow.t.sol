// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SignatureCheckerLib} from "../../../src/utils/SignatureCheckerLib.sol";

import {Base} from "../../base/Base.sol";

contract IsValidSignatureNowTest is Test, Base {
    function setUp() public {}

    function test_isValidSignatureNow_revert_InvalidSignerBytesLength(
        bytes32 hash,
        bytes memory signature,
        bytes memory signerBytes
    ) public {
        vm.assume(signerBytes.length != 32);
        vm.assume(signerBytes.length != 64);

        vm.expectRevert(abi.encodeWithSelector(SignatureCheckerLib.InvalidSignerBytesLength.selector, signerBytes));
        SignatureCheckerLib.isValidSignatureNow(hash, signature, signerBytes);
    }

    function test_isValidSignatureNow_revert_InvalidEthereumAddressSigner(
        bytes32 hash,
        bytes memory signature,
        uint256 signer
    ) public {
        vm.assume(signer > type(uint160).max);

        vm.expectRevert(
            abi.encodeWithSelector(SignatureCheckerLib.InvalidEthereumAddressSigner.selector, abi.encode(signer))
        );
        SignatureCheckerLib.isValidSignatureNow(hash, signature, abi.encode(signer));
    }

    function test_isValidSignatureNow_revert_abiDecodeError(
        bytes32 hash,
        bytes memory signature,
        bytes memory signerBytes
    ) public {
        vm.assume(signerBytes.length == 64);

        vm.expectRevert();
        SignatureCheckerLib.isValidSignatureNow(hash, signature, signerBytes);
    }

    function test_isValidSignatureNow_success_EOA() public pure {
        revert("unimplemented");
    }

    function test_isValidSignatureNow_success_smartContract() public pure {
        revert("unimplemented");
    }

    function test_isValidSignatureNow_success_p256() public pure {
        revert("unimplemented");
    }
}
