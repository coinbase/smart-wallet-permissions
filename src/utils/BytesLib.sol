// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title BytesLib
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
library BytesLib {
    /// @notice Slice call arguments from encoded calldata
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
}
