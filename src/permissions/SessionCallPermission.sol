// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPermissionContract} from "./IPermissionContract.sol";
import {PackedUserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";
import {ISessionCall} from "../utils/ISessionCall.sol";
import {NativeTokenLimitPolicy} from "../policies/NativeTokenLimitPolicy.sol";

/// @title SessionCallPermission
///
/// @notice Only allow calls to SessionCall selector with native token spend limits.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract SessionCallPermission is IPermissionContract, UserOperationUtils, NativeTokenLimitPolicy {

    /// @notice Only allow SessionCalls that do not exceed approved native token spend
    ///
    /// @dev Offchain userOp construction must add a call to registerSpend at the end of the calls array
    function validatePermissions(bytes32 hash, bytes32 sessionHash, bytes calldata permissionData, bytes calldata requestData) external view returns (uint256 validationData) {
        (PackedUserOperation memory userOp) = abi.decode(requestData, (PackedUserOperation));
        _validateUserOperationHash(hash, userOp);
        // check userOp.callData is `executeCalls` (0x34fcd5be)
        (bytes4 selector, bytes memory args) = _splitCallData(userOp.callData);
        if (selector != 0x34fcd5be) revert SelectorNotAllowed();
        // for each call, accumulate attempted spend and check SessionCall function selector
        uint256 attemptSpend = 0;
        (Call[] memory calls) = abi.decode(args, (Call[]));
        for (uint256 i; i < calls.length; i++) {
            // accumulate attemptedSpend
            attemptSpend += calls[i].value;
            // check external calls only `sessionCall`
            if (bytes4(calls[i].data) != ISessionCall.sessionCall.selector || 
                (i == calls.length - 1 && bytes4(calls[i].data) == NativeTokenLimitPolicy.registerSpend.selector)
            ) revert SelectorNotAllowed();
            // validate session call
            // TODO: think about how to combine validationData from multiple calls versus keeping last one
            validationData = ISessionCall(calls[i].target).validateSessionCall(calls[i].data, permissionData);
        }
        if (attemptSpend > 0) {
            // attmpted spend cannot exceed approved spend
            (uint256 approvedSpend) = abi.decode(permissionData, (uint256));
            _validateAttemptSpend(userOp.sender, sessionHash, attemptSpend, approvedSpend);
            // must call this contract with registerSpend(sessionHash, attemptSpend)
            Call memory lastCall = calls[calls.length - 1];
            _validateRegisterSpendCall(sessionHash, attemptSpend, lastCall);
        }
        // TODO: return real validationData
        return 0;
    }
}