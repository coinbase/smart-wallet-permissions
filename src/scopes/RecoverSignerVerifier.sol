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
    function verifyScope(address account, bytes32 hash, bytes32 /*sessionId*/, bytes calldata scopeData, bytes calldata dynamicData) external view {
        UserOperation memory userOp = abi.decode(dynamicData, (UserOperation));

        // check function is addOwnerAddress (0x0f0f3f24) or addOwnerPublicKey (0x29565e3b)
        (bytes4 selector, bytes memory args) = _splitCallData(callData);
        if (selector != 0x34fcd5be && selector != 0x29565e3b) revert UnsupportedFunctionSelector();
    }
}