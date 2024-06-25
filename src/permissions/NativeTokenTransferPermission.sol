// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPermissionContract} from "./IPermissionContract.sol";
import {PackedUserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";
import {NativeTokenLimitPolicy} from "../policies/NativeTokenLimitPolicy.sol";

/// @title NativeTokenTransferPermission
///
/// @dev Supports setting spend limits on a rolling basis, e.g. 1 ETH per week.
///      Supports allowlisting and blocklisting function calls.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract NativeTokenTransferPermission  is IPermissionContract, NativeTokenLimitPolicy {

    error CallDataNotAllowed();

    /// @notice verify that the userOp calls match allowlisted contracts+selectors
    function validatePermissions(bytes32 hash, bytes32 sessionHash, bytes calldata permissionData, bytes calldata requestData) external view returns (uint256) {
        (PackedUserOperation memory userOp) = abi.decode(requestData, (PackedUserOperation));
        _validateUserOperationHash(hash, userOp);
        // check userOp.callData is `executeCalls` (0x34fcd5be)
        (bytes4 selector, bytes memory args) = _splitCallData(userOp.callData);
        if (selector != 0x34fcd5be) revert SelectorNotAllowed();
        // accumulate attempted spend and enforce only native token transfers (no call data)
        uint256 attemptSpend = 0;
        (Call[] memory calls) = abi.decode(args, (Call[]));
        for (uint256 i; i < calls.length; i++) {
            // accumulate attemptedSpend
            attemptSpend += calls[i].value;
            // check external calls only transfers, empty bytes
            if (calls[i].data.length != 0) revert CallDataNotAllowed();
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