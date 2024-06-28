// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {WebAuthn} from "webauthn-sol/WebAuthn.sol";

/// @title SignatureChecker
///
/// @notice Verify signatures for EOAs, smart contracts, and passkeys.
///
/// @dev Wraps SignatureCheckerLib and WebAuthn.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/accounts/ERC4337.sol)
library SignatureChecker {
    /// @notice Thrown when a provided signer is neither 64 bytes long (for public key)
    ///         nor a ABI encoded address.
    ///
    /// @param signer The invalid signer.
    error InvalidSignerBytesLength(bytes signer);

    /// @notice Thrown if a provided signer is 32 bytes long but does not fit in an `address` type.
    ///
    /// @param signer The invalid signer.
    error InvalidEthereumAddressSigner(bytes signer);

    /// @notice Verify signatures over multiple signer types for EOA, smart contract, and passkey.
    ///
    /// @param hash Arbitrary data to sign over.
    /// @param signature Data to verify signer's intent over the `hash`.
    /// @param signerBytes The signer's public key, either type `address` for EOA+SCA or `(bytes32, bytes32)` for passkey.
    ///
    /// @dev temporarily made this a public function for easier testing
    function isValidSignatureNow(bytes32 hash, bytes memory signature, bytes memory signerBytes) public view returns (bool) {
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

        if (signerBytes.length == 64) {
            (uint256 x, uint256 y) = abi.decode(signerBytes, (uint256, uint256));

            WebAuthn.WebAuthnAuth memory auth = abi.decode(signature, (WebAuthn.WebAuthnAuth));

            return WebAuthn.verify({challenge: abi.encode(hash), requireUV: false, webAuthnAuth: auth, x: x, y: y});
        }

        revert InvalidSignerBytesLength(signerBytes);
    }
}