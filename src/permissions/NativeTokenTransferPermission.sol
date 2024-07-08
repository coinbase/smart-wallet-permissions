// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPermissionContract} from "./IPermissionContract.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";
import {NativeTokenSpendLimitPolicy} from "../policies/NativeTokenSpendLimitPolicy.sol";

/// @title NativeTokenTransferPermission
///
/// @dev Supports setting spend limits on a rolling basis, e.g. 1 ETH per week.
///      Supports allowlisting and blocklisting function calls.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract NativeTokenTransferPermission  is IPermissionContract, NativeTokenSpendLimitPolicy {

    error CallDataNotAllowed();

    /// @notice verify that the userOp calls match allowlisted contracts+selectors
    function validatePermission(bytes32 permissionHash, bytes calldata permissionData, UserOperation calldata userOp) external view returns (uint256) {
        // check userOp.callData is `executeCalls` (0x34fcd5be)
        (bytes4 selector, bytes memory args) = _splitCallData(userOp.callData);
        if (selector != 0x34fcd5be) revert SelectorNotAllowed();
        (Call[] memory calls) = abi.decode(args, (Call[]));
        // for each call, accumulate attempted spend and check if call allowed
        uint256 attemptSpend = _validateCalls(permissionHash, calls);
        // check attempted spend does not exceed allowance
        if (attemptSpend > 0) {
            (uint256 allowance) = abi.decode(permissionData, (uint256));
            _validateAllowance(userOp.sender, permissionHash, allowance, attemptSpend);
        }
        return 0;
    }

    function _validateCalls(bytes32 permissionHash, Call[] memory calls) internal view returns (uint256 attemptSpend) {
        uint256 callsLen = calls.length;
        for (uint256 i; i < callsLen; i++) {
            // accumulate pending spend
            attemptSpend += calls[i].value;
            // check if `callWithPermission` (0xb4d42ae1), then only on allowed contract and with arguments matching this permission
            if (i == callsLen - 1 && attemptSpend > 0) {
                _validateAssertCall(permissionHash, attemptSpend, calls[i]);
            // no other call types allowed
            } else if (calls[i].data.length > 0) {
                revert ArgumentsNotAllowed();
            }
        }
        return attemptSpend;
    }
}