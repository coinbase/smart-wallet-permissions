// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPermissionContract} from "./IPermissionContract.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";
import {IPermissionCall} from "../permissionCall/IPermissionCall.sol";
import {NativeTokenSpendLimitPolicy} from "../policies/NativeTokenSpendLimitPolicy.sol";

/// @title PermissionCallPermission
///
/// @notice Only allow calls to PermissionCall selector with native token spend limits.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract PermissionCallPermission is IPermissionContract, UserOperationUtils, NativeTokenSpendLimitPolicy {

    /// @notice Only allow PermissionCalls that do not exceed approved native token spend
    ///
    /// @dev Offchain userOp construction must add a call to registerSpend at the end of the calls array
    function validatePermission(bytes32 permissionHash, bytes calldata permissionData, UserOperation calldata userOp) external view returns (uint256 validationData) {
        // check userOp.callData is `executeBatch` (0x34fcd5be)
        (bytes4 selector, bytes memory args) = _splitCallData(userOp.callData);
        if (selector != 0x34fcd5be) revert SelectorNotAllowed();
        // for each call, accumulate attempted spend and check PermissionCall function selector
        uint256 attemptSpend = 0;
        (Call[] memory calls) = abi.decode(args, (Call[]));
        for (uint256 i; i < calls.length; i++) {
            // accumulate attemptedSpend
            attemptSpend += calls[i].value;
            // check external calls only `permissionCall` or `assertSpend` on last call
            bytes4 callSelector = bytes4(calls[i].data);
            bool isPermissionCall = callSelector == 0xcb56e602; // `permissionCall`
            bool isLastCallAndAttemptSpendAndAssertSpend = i == calls.length - 1 && attemptSpend > 0 && callSelector == 0xd74b930e; // `assertSpend`
            if (!isPermissionCall && !isLastCallAndAttemptSpendAndAssertSpend) revert SelectorNotAllowed();
        }
        if (attemptSpend > 0) {
            // attempted spend cannot exceed allowance
            (uint256 allowance) = abi.decode(permissionData, (uint256));
            _validateAllowance(userOp.sender, permissionHash, allowance, attemptSpend);
            // must call this contract with assertSpend(assertBalance, permissionHash, attemptSpend)
            _validateAssertCall(permissionHash, attemptSpend, calls);
        }
        // TODO: return real validationData
        return 0;
    }
}