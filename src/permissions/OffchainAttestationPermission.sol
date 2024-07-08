// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

import {IPermissionContract} from "./IPermissionContract.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";

/// @title OffchainAttestationPermission
///
/// @notice Trust a third-party to verify conditions offchain and sign attestations.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract OffchainAttestationPermission is IPermissionContract, UserOperationUtils {
    function validatePermission(bytes32 /*permissionHash*/, bytes calldata permissionData, UserOperation calldata userOp) external view returns (uint256) {
        address attestor = abi.decode(permissionData, (address));
        bool isValid = SignatureCheckerLib.isValidSignatureNow(attestor, _hashUserOperation(userOp), userOp.signature);
        return isValid ? 0 : 1; // sigFailed = 0 when signature valid and 1 when signature invalid
    }
}