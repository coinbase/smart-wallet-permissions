// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {LibString} from "solady/utils/LibString.sol";

/// @title BytesLib
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
library BytesLib {
    /// @notice Trim selector out of call data.
    ///
    /// @param callData Encoded data for an external contract call.
    ///
    /// @return args Arguments of the call data, now with selector trimmed out.
    function trimSelector(bytes memory callData) internal pure returns (bytes memory args) {
        return bytes(LibString.slice(string(callData), 4));
    }

    /// @notice Check equivalence of two bytes variables.
    ///
    /// @param a Bytes to compare
    /// @param b Bytes to compare
    ///
    /// @return eq True if equivalent.
    function eq(bytes memory a, bytes memory b) internal pure returns (bool) {
        return LibString.eq(string(a), string(b));
    }
}
