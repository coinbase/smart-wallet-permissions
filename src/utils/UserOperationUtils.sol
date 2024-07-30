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
contract UserOperationUtils {
    address constant ENTRYPOINT_V06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    // executeBatch((address,uint256,bytes)[])
    bytes4 public constant EXECUTE_BATCH_SELECTOR = 0x34fcd5be;

    /// @notice Represents a call to make from the account.
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    /// @notice UserOperation does not match provided hash.
    error InvalidUserOperationHash();

    /// @notice UserOperation sender does not match account.
    error InvalidUserOperationSender();

    /// @notice Function selector not allowed.
    error SelectorNotAllowed();

    /// @notice Target contract not allowed.
    error ContractNotAllowed();

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
    function _sliceCallArgs(bytes memory callData) internal pure returns (bytes memory args) {
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

    function _validateUserOperationHash(bytes32 hash, UserOperation memory userOp) internal view {
        if (IEntryPoint(ENTRYPOINT_V06).getUserOpHash(userOp) != hash) revert InvalidUserOperationHash();
    }

    function _validateUserOperationSender(address sender, address account) internal pure {
        if (sender != account) revert InvalidUserOperationSender();
    }
}
