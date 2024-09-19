// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SignatureCheckerLib} from "../../../../src/utils/SignatureCheckerLib.sol";

import {Base} from "../../../base/Base.sol";
import {MockContractSigner} from "../../../mocks/MockContractSigner.sol";

contract IsValidSignatureNowTest is Test, Base {
    function setUp() public {
        _initializeBase();
    }

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

    function test_isValidSignatureNow_success_EOA(bytes32 hash, uint256 privateKey) public view {
        // private key must be less than the secp256k1 curve order
        vm.assume(privateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337);
        vm.assume(privateKey != 0);

        address signer = vm.addr(privateKey);
        bytes memory signature = _sign(privateKey, hash);
        assertTrue(SignatureCheckerLib.isValidSignatureNow(hash, signature, abi.encode(signer)));
    }

    function test_isValidSignatureNow_success_smartContract(bytes32 hash, uint256 privateKey) public {
        // private key must be less than the secp256k1 curve order
        vm.assume(privateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337);
        vm.assume(privateKey != 0);

        address signer = vm.addr(privateKey);
        bytes memory signature = _sign(privateKey, hash);

        MockContractSigner contractSigner = new MockContractSigner(signer);
        assertTrue(SignatureCheckerLib.isValidSignatureNow(hash, signature, abi.encode(address(contractSigner))));
    }

    function test_isValidSignatureNow_success_p256(bytes32 hash) public view {
        bytes memory signature = _signP256(p256PrivateKey, hash);

        assertTrue(SignatureCheckerLib.isValidSignatureNow(hash, signature, p256PublicKey));
    }
}
