// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title CallErrors
///
/// @notice Shared errors for validating permissioned user operations.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
library CallErrors {
    /// @notice Call target not allowed.
    ///
    /// @param target Address target of a call.
    error TargetNotAllowed(address target);

    /// @notice Call function selector not allowed.
    ///
    /// @param selector Function selector of a call.
    error SelectorNotAllowed(bytes4 selector);

    /// @notice Call value not allowed.
    ///
    /// @param value Value of a call.
    error ValueNotAllowed(uint256 value);

    /// @notice Call length under 4 bytes.
    error InvalidCallLength();
}
