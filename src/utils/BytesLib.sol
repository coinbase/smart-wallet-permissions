// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {LibString} from "solady/utils/LibString.sol";

/// @title BytesLib
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
library BytesLib {
    function trimSelector(bytes memory callData) internal pure returns (bytes memory args) {
        return bytes(LibString.slice(string(callData), 4));
    }

    function eq(bytes memory a, bytes memory b) internal pure returns (bool) {
        return LibString.eq(string(a), string(b));
    }
}
