// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation, UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

/// @title UserOperationUtils
///
/// @notice Utilities for user operations on Entrypoint V0.6
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
library UserOperationUtils {
    address constant ENTRY_POINT_V06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    /// @notice UserOperation does not match provided hash.
    error InvalidUserOperationHash();

    /// @notice UserOperation sender does not match account.
    error InvalidUserOperationSender();

    /// @notice Function selector not allowed.
    error SelectorNotAllowed();

    /// @notice Call target not allowed.
    error TargetNotAllowed();

    /// @notice Call arguments not allowed.
    error ArgumentsNotAllowed();

    /// @notice UserOperation callData is invalid.
    error InvalidUserOperationCallData();

    /// @notice Slice call arguments from a call's data field
    ///
    /// @dev ~7% increase of gas usage relative to calldata slicing
    ///
    /// @param callData the data of the external call
    ///
    /// @return args the arguments of the call with the selector parsed out
    function sliceCallArgs(bytes memory callData) internal pure returns (bytes memory args) {
        assembly {
            // calculate the length of the new args array (subtract 4 from the callData length)
            let len := sub(mload(callData), 4)
            // allocate memory for the new args array
            args := mload(0x40)
            // set the length of the new args array
            mstore(args, len)
            // update the free memory pointer
            mstore(0x40, add(args, add(len, 0x20)))

            // initialize source and destination pointers
            let src := add(callData, 0x24) // start copying from callData + 4 bytes (0x20 + 4)
            let dest := add(args, 0x20) // start storing at args + 0x20

            // calculate the end pointer for the source args
            let end := add(src, len)

            // copy bytes from callData to the new args array in chunks of 32 bytes
            for {} lt(src, end) {
                src := add(src, 0x20)
                dest := add(dest, 0x20)
            } {
                // load 32 bytes from the source
                let chunk := mload(src)
                // store the loaded 32 bytes into the destination
                mstore(dest, chunk)
            }
        }
    }

    /// @notice Calculate the requiredPrefund amount reserved by Entrypoint to pay for gas
    ///
    /// @dev Gas not consumed gets refunded to the sponsoring party (user account or paymaster) in postOp process
    /// @dev Implementation forked from
    ///      https://github.com/eth-infinitism/account-abstraction/blob/releases/v0.6/contracts/core/EntryPoint.sol#L325
    function getRequiredPrefund(UserOperation calldata userOp) internal pure returns (uint256 requiredPrefund) {
        // if using paymaster, use a multiplier for verificationGasLimit
        uint256 mul = address(bytes20(userOp.paymasterAndData[:20])) != address(0) ? 3 : 1;
        // sum gas parameters
        uint256 requiredGas = userOp.callGasLimit + mul * userOp.verificationGasLimit + userOp.preVerificationGas;
        // calculate max gas fees required for prefund
        requiredPrefund = requiredGas * userOp.maxFeePerGas;
    }

    function getUserOpHash(UserOperation memory userOp) internal view returns (bytes32) {
        return IEntryPoint(ENTRY_POINT_V06).getUserOpHash(userOp);
    }
}
