// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";

/// @title UserOperationLib
///
/// @notice Utilities for user operations on Entrypoint V0.6.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
library UserOperationLib {
    address constant ENTRY_POINT_V06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    /// NOTE: Why do we define errors here? it looks like they are only used in one file, and they are not used here? 
    /// @notice UserOperation does not match provided hash.
    ///
    /// @param userOpHash Hash of the user operation.
    error InvalidUserOperationHash(bytes32 userOpHash);

    /// @notice UserOperation sender does not match account.
    ///
    /// @param sender Account that the user operation is made from.
    error InvalidUserOperationSender(address sender);

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

    /// @notice Calculate the requiredPrefund amount reserved by Entrypoint to pay for gas.
    ///
    /// @dev Gas not consumed gets refunded to the sponsoring party (user account or paymaster) in postOp process.
    /// @dev Implementation forked from
    /// NIT: user permalink 
    /// https://github.com/eth-infinitism/account-abstraction/blob/fa61290d37d079e928d92d53a122efcc63822214/contracts/core/EntryPoint.sol#L325
    ///      https://github.com/eth-infinitism/account-abstraction/blob/releases/v0.6/contracts/core/EntryPoint.sol#L325
    ///
    /// @param userOp User operation struct.
    ///
    /// @return requiredPrefund Amount of native token withheld by EntryPoint to cover gas fee for bundler.
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
    ///
    /// @return userOpHash Hash of the user operation.
    function getUserOpHash(UserOperation memory userOp) internal view returns (bytes32) {
        return IEntryPoint(ENTRY_POINT_V06).getUserOpHash(userOp);
    }

    /// @notice Get paymaster address from paymasterAndData
    ///
    /// @param paymasterAndData Field from user operation for paymaster contract and data.
    ///
    /// @return paymaster Address of contract or address(0) if no paymaster used.
    function getPaymaster(bytes memory paymasterAndData) internal pure returns (address paymaster) {
        /// note: do you need this conditional? wouldn't it return address(0) either way? 
        return paymasterAndData.length == 0 ? address(0) : address(bytes20(paymasterAndData));
    }
}
