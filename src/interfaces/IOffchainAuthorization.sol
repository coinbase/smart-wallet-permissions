// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title IOffchainAuthorization
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
interface IOffchainAuthorization {
    /// @notice Indicate if an offchain request comes from a signer authorized by this contract.
    enum Authorization {
        UNAUTHORIZED, // show warning + reject request
        UNVERIFIED, // show caution
        VERIFIED // show okay

    }

    /// @notice Verify offchain if a request is authorized by this contract.
    ///
    /// @param hash Hash of the request
    /// @param authData Arbitrary data used to validate authorization
    function getRequestAuthorization(bytes32 hash, bytes calldata authData) external view returns (Authorization);
}
