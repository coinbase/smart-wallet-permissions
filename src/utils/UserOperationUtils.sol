// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation, UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";

/// @title UserOperationUtils
///
/// @notice Utilities for user operations on Entrypoint V0.6.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
library UserOperationUtils {
    address constant ENTRY_POINT_V06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    /// @notice UserOperation does not match provided hash.
    error InvalidUserOperationHash();

    /// @notice UserOperation sender does not match account.
    error InvalidUserOperationSender();

    /// @notice Call target not allowed.
    error TargetNotAllowed();

    /// @notice Call function selector not allowed.
    error SelectorNotAllowed();

    /// @notice Call function arguments not allowed.
    error ArgumentsNotAllowed();

    /// @notice UserOperation callData is invalid.
    error InvalidUserOperationCallData();

    /// @notice Calculate the requiredPrefund amount reserved by Entrypoint to pay for gas.
    ///
    /// @dev Gas not consumed gets refunded to the sponsoring party (user account or paymaster) in postOp process.
    /// @dev Implementation forked from
    ///      https://github.com/eth-infinitism/account-abstraction/blob/releases/v0.6/contracts/core/EntryPoint.sol#L325
    function getRequiredPrefund(UserOperation calldata userOp) internal pure returns (uint256 requiredPrefund) {
        // if using paymaster, use a multiplier for verificationGasLimit
        uint256 mul = userOp.paymasterAndData.length == 0 ? 1 : 3;
        // sum gas parameters
        uint256 requiredGas = userOp.callGasLimit + mul * userOp.verificationGasLimit + userOp.preVerificationGas;
        // calculate max gas fees required for prefund
        requiredPrefund = requiredGas * userOp.maxFeePerGas;
    }

    /// @notice Get the userOpHash for a userOp.
    ///
    /// @dev Hardcoded to use EntryPoint v0.6.
    ///
    /// @param userOp User operation to hash.
    function getUserOpHash(UserOperation memory userOp) internal view returns (bytes32) {
        return IEntryPoint(ENTRY_POINT_V06).getUserOpHash(userOp);
    }
}
