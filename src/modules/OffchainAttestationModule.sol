// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

import {IPermissionModule} from "./IPermissionModule.sol";

/// @title OffchainAttestationModule
///
/// @notice Trust a third-party to verify conditions offchain and sign attestations.
///
/// @dev Most flexible verification logic.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract OffchainAttestationModule is IPermissionModule {
    function validatePermissions(address /*account*/, bytes32 hash, bytes32 /*sessionId*/, bytes calldata permissionData, bytes calldata requestData) external view {
        bytes memory attestation = abi.decode(requestData, (bytes));
        address attestor = abi.decode(permissionData, (address));

        // check attestation
        SignatureCheckerLib.isValidSignatureNow(attestor, hash, attestation);
    }
}