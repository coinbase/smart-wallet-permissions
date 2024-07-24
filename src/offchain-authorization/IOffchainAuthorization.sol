// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title IOffchainAuthorization
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
interface IOffchainAuthorization {
    /// @notice Indicator if an offchain request comes from a signer authorized by this contract.
    enum Authorization {
        UNAUTHORIZED, // should show warning label and block requests
        UNPROTECTED, // should show caution label
        PUBLIC, // should show okay label
        AUTHORIZED // should show secure label
    }

    /// @notice Verify offchain if a permission is authorized by this contract.
    ///
    /// @param hash Hash of the Permission
    /// @param authData Arbitrary data used to validate authorization
    function isAuthorizedRequest(bytes32 hash, bytes calldata authData) external view returns (Authorization);
}
