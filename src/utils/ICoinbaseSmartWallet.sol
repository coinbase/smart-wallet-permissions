// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICoinbaseSmartWallet {
    /// @notice Represents a call to make.
    struct Call {
        /// @dev The address to call.
        address target;
        /// @dev The value to send when making the call.
        uint256 value;
        /// @dev The data of the call.
        bytes data;
    }

    function executeBatch(Call[] calldata calls) external payable;
}
