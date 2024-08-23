// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {WebAuthn} from "webauthn-sol/WebAuthn.sol";

/// @title P256SignatureCheckerLib
///
/// @notice Verify signatures for ethereum addresses (EOAs, smart contracts) and secp256r1 keys (passkeys, cryptokeys).
/// @notice Forked from official implementation in Coinbase Smart Wallet.
///
/// @dev Wraps SignatureCheckerLib and WebAuthn.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/accounts/ERC4337.sol)
library P256SignatureCheckerLib {
    /// @notice Thrown when a provided signer is neither 64 bytes long (for public key)
    ///         nor a ABI encoded address.
    ///
    /// @param signer The invalid signer.
    error InvalidSignerBytesLength(bytes signer);

    /// @notice Thrown if a provided signer is 32 bytes long but does not fit in an `address` type.
    ///
    /// @param signer The invalid signer.
    error InvalidEthereumAddressSigner(bytes signer);

    /// @notice Verify signatures for Ethereum addresses or P256 public keys.
    ///
    /// @param hash Arbitrary data to sign over.
    /// @param signature Data to verify signer's intent over the `hash`.
    /// @param signerBytes The signer, type `address` or `(bytes32, bytes32)`
    function isValidSignatureNow(bytes32 hash, bytes memory signature, bytes memory signerBytes)
        internal
        view
        returns (bool)
    {
        // signer is an ethereum address (EOA or smart contract)
        if (signerBytes.length == 32) {
            if (uint256(bytes32(signerBytes)) > type(uint160).max) {
                // technically should be impossible given signers can only be added with
                // addSignerAddress and addSignerPublicKey, but we leave incase of future changes.
                revert InvalidEthereumAddressSigner(signerBytes);
            }

            address signer;
            assembly ("memory-safe") {
                signer := mload(add(signerBytes, 32))
            }

            return SignatureCheckerLib.isValidSignatureNow(signer, hash, signature);
        }

        // signer is a secp256r1 key using WebAuthn
        if (signerBytes.length == 64) {
            (uint256 x, uint256 y) = abi.decode(signerBytes, (uint256, uint256));

            WebAuthn.WebAuthnAuth memory auth = abi.decode(signature, (WebAuthn.WebAuthnAuth));

            return WebAuthn.verify({challenge: abi.encode(hash), requireUV: false, webAuthnAuth: auth, x: x, y: y});
        }

        revert InvalidSignerBytesLength(signerBytes);
    }
}
