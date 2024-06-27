// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

import {IPermissionContract} from "./IPermissionContract.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";

/// @title OffchainAttestationPermission
///
/// @notice Trust a third-party to verify conditions offchain and sign attestations.
///
/// @dev Most flexible verification logic.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract OffchainAttestationPermission is IPermissionContract, UserOperationUtils {
    function validatePermission(address account, bytes32 hash, bytes32 /*sessionHash*/, bytes calldata permissionData, bytes calldata requestData) external view returns (uint256) {
        (UserOperation memory userOp) = abi.decode(requestData, (UserOperation));
        // check userOperation matches hash
        _validateUserOperationHash(hash, userOp);
        // check userOperation sender matches account;
        _validateUserOperationSender(account, userOp.sender);
        // check attestation
        address attestor = abi.decode(permissionData, (address));
        SignatureCheckerLib.isValidSignatureNow(attestor, hash, userOp.signature);
        // TODO: return real validationData
        return 0;
    }
}