// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserOperation, UserOperationUtils} from "../../utils/UserOperationUtils.sol";
import {IPermissionContract} from "../IPermissionContract.sol";
import {IPermissionCallable} from "./IPermissionCallable.sol";

import {RollingNativeTokenSpendLimit} from "./RollingNativeTokenSpendLimit.sol";

/// @title CallWithPermission
///
/// @notice Only allow calls to IPermissionCallable selector with native token spend limits.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract CallWithPermission is IPermissionContract, UserOperationUtils, RollingNativeTokenSpendLimit {
    /// @notice Only allow callWithPermissions that do not exceed approved native token spend.
    ///
    /// @dev Offchain userOp construction should add a call to registerSpend at the end of the calls array.
    /// @dev Offchain userOp construction should wrap calls with the proper permissionHash and permissionArgs.
    /// @dev Rolling native token spend accounting does not protect against re-entrancy where an external call could
    ///      trigger an authorized call back to the account to spend more ETH.
    /// @dev Rolling native token spend accounting overestimates ETH spent via gas when a paymaster is not used.
    function validatePermission(bytes32 permissionHash, bytes calldata permissionData, UserOperation calldata userOp)
        external
        view
    {
        bytes4 selector = bytes4(userOp.callData[0:4]);
        // check userOp.callData is `executeBatch`
        if (selector != EXECUTE_BATCH_SELECTOR) revert SelectorNotAllowed();

        (uint256 spendLimit, uint256 spendPeriod, address allowedContract, bytes memory permissionArgs) =
            abi.decode(permissionData, (uint256, uint256, address, bytes));

        // for each call, accumulate attempted spend and check if call allowed
        Call[] memory calls = abi.decode(userOp.callData[4:], (Call[]));
        uint256 callsLen = calls.length;
        uint256 spendValue = 0;
        // if no paymaster, set initial spendValue as requiredPrefund
        /// @dev note that there is no accounting for the refund step so ETH spend is overestimated slightly.
        if (userOp.paymasterAndData.length == 0) {
            spendValue += _getRequiredPrefund(userOp);
        }
        for (uint256 i; i < callsLen; i++) {
            // accumulate spend value
            spendValue += calls[i].value;
            // check if last call and nonzero spend value, then this is assertSpend call
            if (i == callsLen - 1 && spendValue > 0) {
                _validateAssertSpendCall(spendValue, permissionHash, spendLimit, spendPeriod, calls[i]);
            } else if (bytes4(calls[i].data) == IPermissionCallable.callWithPermission.selector) {
                // check call target is the allowed contract
                if (calls[i].target != allowedContract) {
                    revert TargetNotAllowed();
                }
                // check the args for `callWithPermission` match this permission
                (bytes32 callPermissionHash, bytes memory callPermissionArgs,) =
                    abi.decode(_sliceCallArgs(calls[i].data), (bytes32, bytes, bytes));
                if (callPermissionHash != permissionHash || keccak256(callPermissionArgs) != keccak256(permissionArgs))
                {
                    revert ArgumentsNotAllowed();
                }
                // no other call types allowed
            } else {
                revert SelectorNotAllowed();
            }
        }
    }
}
