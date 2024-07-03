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
            (uint256 allowance) = abi.decode(permissionData, (uint256));
            _validateAllowance(userOp.sender, permissionHash, allowance, attemptSpend);
            // must call this contract with registerSpend(permissionHash, attemptSpend)
            _validateAssertCall(permissionHash, attemptSpend, calls);
        }
        // TODO: return real validationData
        return 0;
    }
}