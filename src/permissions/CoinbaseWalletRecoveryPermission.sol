// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPermissionContract} from "./IPermissionContract.sol";
import {PackedUserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";

/// @title CoinbaseWalletRecoveryPermission
///
/// @notice Trust a third-party to recover signers in the event of loss of primary keys used to control a Coinbase Smart Wallet.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract CoinbaseWalletRecoveryPermission is IPermissionContract, UserOperationUtils {
    function validatePermissions(bytes32 hash, bytes32 /*sessionHash*/, bytes calldata /*permissionData*/, bytes calldata requestData) external pure returns (uint256) {
        (PackedUserOperation memory userOp) = abi.decode(requestData, (PackedUserOperation));
        _validateUserOperationHash(hash, userOp);
        // check userOp.callData is executeWithoutChainIdValidation (0x2c2abd1e)
        (bytes4 selector, bytes memory args) = _splitCallData(userOp.callData);
        if (selector != 0x2c2abd1e) revert SelectorNotAllowed();
        // check self-calls are only addOwnerAddress (0x0f0f3f24) or addOwnerPublicKey (0x29565e3b)
        (bytes[] memory calls) = abi.decode(args, (bytes[]));
        for (uint256 i; i < calls.length; i++) {
            if (bytes4(calls[i]) != 0x0f0f3f24 && bytes4(calls[i]) != 0x29565e3b) {
                revert SelectorNotAllowed();
            }
        }
        // TODO: return real validationData
        return 0;
    }
}