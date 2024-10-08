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
