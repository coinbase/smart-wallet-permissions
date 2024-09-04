// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation, UserOperationLib as InnerLib} from "account-abstraction/interfaces/UserOperation.sol";

/// @title UserOperationLib
///
/// @notice Utilities for user operations on Entrypoint V0.6.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
library UserOperationLib {
    address constant ENTRY_POINT_V06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    /// @notice Calculate the requiredPrefund amount reserved by Entrypoint to pay for gas.
    ///
    /// @dev Gas not consumed gets refunded to the sponsoring party (user account or paymaster) in postOp process.
    /// @dev Implementation forked from
    ///      https://github.com/eth-infinitism/account-abstraction/blob/fa61290d37d079e928d92d53a122efcc63822214/contracts/core/EntryPoint.sol#L325
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
        bytes32 innerHash = keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                keccak256(userOp.paymasterAndData)
            )
        );
        return keccak256(abi.encode(innerHash, ENTRY_POINT_V06, block.chainid));
    }
}
