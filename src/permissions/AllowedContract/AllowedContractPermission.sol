// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ICoinbaseSmartWallet} from "../../utils/ICoinbaseSmartWallet.sol";
import {UserOperation, UserOperationUtils} from "../../utils/UserOperationUtils.sol";
import {IPermissionContract} from "../IPermissionContract.sol";
import {IPermissionCallable} from "./IPermissionCallable.sol";

import {RollingNativeTokenSpendLimit} from "./RollingNativeTokenSpendLimit.sol";

/// @title AllowedContractPermission
///
/// @notice Only allow calls to an allowed contract's IPermissionCallable selector.
/// @notice Supports spending native token with rolling limits.
///
/// @dev Called by PermissionManager at end of its validation flow.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract AllowedContractPermission is IPermissionContract, RollingNativeTokenSpendLimit {
    /// @notice Only allow permissioned calls that do not exceed approved native token spend.
    ///
    /// @dev Offchain userOp construction should append assertSpend call to calls array if spending value.
    /// @dev Rolling native token spend accounting does not protect against re-entrancy where an external call could
    ///      trigger an authorized call back to the account to spend more ETH.
    /// @dev Rolling native token spend accounting overestimates ETH spent via gas when a paymaster is not used.
    function validatePermission(bytes32 permissionHash, bytes calldata permissionData, UserOperation calldata userOp)
        external
        view
    {
        /// @dev TODO: pack spendLimit and spendPeriod
        (uint256 spendLimit, uint256 spendPeriod, address allowedContract) =
            abi.decode(permissionData, (uint256, uint256, address));

        // for each call, accumulate attempted spend and check if call allowed
        // assumes PermissionManager already enforces use of `executeBatch` selector
        ICoinbaseSmartWallet.Call[] memory calls = abi.decode(userOp.callData[4:], (ICoinbaseSmartWallet.Call[]));
        uint256 callsLen = calls.length;
        uint256 spendValue = 0;
        // if no paymaster, set initial spendValue as requiredPrefund
        /// @dev no accounting done for the refund step so ETH spend is overestimated slightly
        if (userOp.paymasterAndData.length == 0) {
            spendValue += UserOperationUtils.getRequiredPrefund(userOp);
        }
        // ignore first call, enforced by PermissionManager as validation call on itself
        for (uint256 i = 1; i < callsLen; i++) {
            // accumulate spend value
            spendValue += calls[i].value;
            // check if last call and nonzero spend value, then this must be assertSpend call
            if (i == callsLen - 1 && spendValue > 0) {
                _validateAssertSpendCall(spendValue, permissionHash, spendLimit, spendPeriod, calls[i]);
            } else if (bytes4(calls[i].data) == IPermissionCallable.permissionedCall.selector) {
                // check call target is the allowed contract
                // assume PermissionManager already prevents account as target
                if (calls[i].target != allowedContract) revert UserOperationUtils.TargetNotAllowed();
            } else {
                revert UserOperationUtils.SelectorNotAllowed();
            }
        }
    }
}
