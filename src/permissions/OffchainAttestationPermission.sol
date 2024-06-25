// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

import {IPermissionContract} from "./IPermissionContract.sol";
import {PackedUserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";

/// @title OffchainAttestationPermission
///
/// @notice Trust a third-party to verify conditions offchain and sign attestations.
///
/// @dev Most flexible verification logic.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract OffchainAttestationPermission is IPermissionContract, UserOperationUtils {
    function validatePermissions(bytes32 hash, bytes32 /*sessionHash*/, bytes calldata permissionData, bytes calldata requestData) external view returns (uint256) {
        (PackedUserOperation memory userOp) = abi.decode(requestData, (PackedUserOperation));
        _validateUserOperationHash(hash, userOp);
        // check attestation
        address attestor = abi.decode(permissionData, (address));
        SignatureCheckerLib.isValidSignatureNow(attestor, hash, userOp.signature);
        // TODO: return real validationData
        return 0;
    }
}