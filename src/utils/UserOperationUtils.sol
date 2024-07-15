// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserOperation, UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

/// @title UserOperationUtils
///
/// @notice Utilities for user operations on Entrypoint V0.6
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract UserOperationUtils {

    address constant ENTRYPOINT_V06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

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
    
    /// @notice split encoded function call into selector and arguments
    function _splitCallData(bytes memory callData) internal pure returns (bytes4 selector, bytes memory args) {
        if (callData.length <= 4) revert InvalidUserOperationCallData();
        bytes memory trimmed = new bytes(callData.length - 4);
        for (uint i = 4; i < callData.length; i++) {
            trimmed[i - 4] = callData[i];
        }
        return (bytes4(callData), trimmed);
    }

    /// @dev TODO: couldn't get UserOperationLib to work with UserOperation memory type and needed a quick fix for build errors, we should find something less brute-forcey
    function _hashUserOperation(UserOperation memory userOp) internal view returns (bytes32) {
        address sender = userOp.sender;
        uint256 nonce = userOp.nonce;
        bytes32 hashInitCode = keccak256(userOp.initCode);
        bytes32 hashCallData = keccak256(userOp.callData);
        uint256 callGasLimit = userOp.callGasLimit;
        uint256 verificationGasLimit = userOp.verificationGasLimit;
        uint256 preVerificationGas = userOp.preVerificationGas;
        uint256 maxFeePerGas = userOp.maxFeePerGas;
        uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        bytes32 hashPaymasterAndData = keccak256(userOp.paymasterAndData);

        bytes32 innerHash = keccak256(abi.encode(
            sender, nonce,
            hashInitCode, hashCallData,
            callGasLimit, verificationGasLimit, preVerificationGas,
            maxFeePerGas, maxPriorityFeePerGas,
            hashPaymasterAndData
        ));

        return keccak256(abi.encode(innerHash, ENTRYPOINT_V06, block.chainid));
    }

    function _validateUserOperationHash(bytes32 hash, UserOperation memory userOp) internal view {
        if (_hashUserOperation(userOp) != hash) revert InvalidUserOperationHash();
    }
    
    function _validateUserOperationSender(address account, address sender) internal pure {
        if (sender != account) revert InvalidUserOperationSender();
    }
}