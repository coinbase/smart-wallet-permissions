// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

import {IPermissionModule} from "./IPermissionModule.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";

/// @title OnlySessionKeyCallModule
///
/// @notice Only allow session keys to call a specific function selector on external contracts.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract OnlySessionKeyCallModule is IPermissionModule {
    function validatePermissions(address account, bytes32 hash, bytes32 /*sessionId*/, bytes calldata /*permissionData*/, bytes calldata requestData) external pure {
        UserOperation memory userOp = abi.decode(requestData, (UserOperation));

        // check userOp matches hash
        if (_hashUserOperation(userOp) != hash) revert InvalidUserOperationHash();
        // check userOp sender matches account
        if (userOp.sender != account) revert InvalidUserOperationSender();
        // check userOp.callData is executeCalls (0x34fcd5be)
        (bytes4 selector, bytes memory args) = _splitCallData(userOp.callData);
        if (selector != 0x34fcd5be) revert SelectorNotAllowed();
        // check external calls only `sessionKeyCall` (0x93a9f8ce)
        /// @dev probably also want to apply some checks on allowed contracts or ETH spend?
        (bytes[] memory calls) = abi.decode(args, (bytes[]));
        for (uint256 i; i < calls.length; i++) {
            if (bytes4(calls[i]) != 0x93a9f8ce) revert SelectorNotAllowed();
        }
    }
}