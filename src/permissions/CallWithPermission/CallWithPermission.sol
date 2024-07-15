// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPermissionContract} from "../IPermissionContract.sol";
import {UserOperation, UserOperationUtils} from "../../utils/UserOperationUtils.sol";
import {NativeTokenSpendLimitPolicy} from "../../policies/NativeTokenSpendLimitPolicy.sol";

/// @title CallWithPermission
///
/// @notice Only allow calls to IPermissionCallable selector with native token spend limits.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract CallWithPermission is IPermissionContract, UserOperationUtils, NativeTokenSpendLimitPolicy {
    /// @notice Only allow callWithPermissions that do not exceed approved native token spend.
    ///
    /// @dev Offchain userOp construction should add a call to registerSpend at the end of the calls array.
    /// @dev Offchain userOp construction should wrap calls with the proper permissionHash and permissionArgs.
    function validatePermission(bytes32 permissionHash, bytes calldata permissionData, UserOperation calldata userOp) external view returns (uint256 validationData) {
        // check userOp.callData is `executeBatch` (0x34fcd5be)
        (bytes4 selector, bytes memory args) = _splitCallData(userOp.callData);
        if (selector != 0x34fcd5be) revert SelectorNotAllowed();
        (Call[] memory calls) = abi.decode(args, (Call[]));
        // for each call, accumulate attempted spend and check if call allowed
        uint256 attemptSpend = _validateCalls(permissionHash, permissionData, calls);
        // check attempted spend does not exceed allowance
        if (attemptSpend > 0) {
            (uint256 allowance, /*address allowedContract*/, /*bytes permissionArgs*/) = abi.decode(permissionData, (uint256, address, bytes));
            _validateAllowance(userOp.sender, permissionHash, allowance, attemptSpend);
        }
        return 0;
    }

    function _validateCalls(bytes32 permissionHash, bytes memory permissionData, Call[] memory calls) internal view returns (uint256 attemptSpend) {
        uint256 callsLen = calls.length;
        for (uint256 i; i < callsLen; i++) {
            // accumulate pending spend
            attemptSpend += calls[i].value;
            (bytes4 callSelector, bytes memory callArgs) = _splitCallData(calls[i].data);
            // check if `callWithPermission` (0xb4d42ae1), then only on allowed contract and with arguments matching this permission
            if (callSelector == 0xb4d42ae1) {
                (/*uint256 allowance*/, address allowedContract, bytes memory permissionArgs) = abi.decode(permissionData, (uint256, address, bytes));
                // check call target is the allowed contract
                if (calls[i].target != allowedContract) revert ContractNotAllowed();
                (bytes32 callPermissionHash, bytes memory callPermissionArgs,) = abi.decode(callArgs, (bytes32, bytes, bytes));
                // check the args for `callWithPermission` match this permission
                if (callPermissionHash != permissionHash || keccak256(callPermissionArgs) != keccak256(permissionArgs)) {
                    revert ArgumentsNotAllowed();
                }
            // check if last call and attempting spend, then this is balance assert call
            } else if (i == callsLen - 1 && attemptSpend > 0) {
                _validateAssertCall(permissionHash, attemptSpend, calls[i]);
            // no other call types allowed
            } else {
                revert SelectorNotAllowed();
            }
        }
        return attemptSpend;
    }
}