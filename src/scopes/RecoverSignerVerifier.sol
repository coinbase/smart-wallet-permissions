// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IScopeVerifier} from "./IScopeVerifier.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";

/// @title RecoverySignerVerifier
///
/// @notice Trust a third-party to recover signers in the event of loss of primary keys used to control an account.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract RecoverySignerVerifier is IScopeVerifier, UserOperationUtils {
    function verifyScope(address account, bytes32 hash, bytes32 /*sessionId*/, bytes calldata /*scopeData*/, bytes calldata dynamicData) external pure {
        UserOperation memory userOp = abi.decode(dynamicData, (UserOperation));

        // check userOp matches hash
        if (_hashUserOperation(userOp) != hash) revert InvalidUserOperationHash();
        // check userOp sender matches account
        if (userOp.sender != account) revert InvalidUserOperationSender();
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
    }
}