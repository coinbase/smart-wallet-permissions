// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

import {IScopeVerifier} from "./IScopeVerifier.sol";

/// @title OffchainAttestationVerifier
///
/// @notice Trust a third-party to verify conditions offchain and sign attestations.
///
/// @dev Most flexible verification logic.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract OffchainAttestationVerifier is IScopeVerifier {
    function verifyScope(address /*account*/, bytes32 hash, bytes32 /*sessionId*/, bytes calldata scopeData, bytes calldata dynamicData) external view {
        bytes memory attestation = abi.decode(dynamicData, (bytes));
        address attestor = abi.decode(scopeData, (address));

        // check attestation
        SignatureCheckerLib.isValidSignatureNow(attestor, hash, attestation);
    }
}