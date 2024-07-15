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
    bytes4 constant public EXECUTE_BATCH_SELECTOR = 0x34fcd5be;

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
    ///
    /// @dev only needed for when working with bytes memory, use [i:j] for calldata
    function _splitCallData(bytes memory callData) internal pure returns (bytes4 selector, bytes memory args) {
        if (callData.length <= 4) revert InvalidUserOperationCallData();
        bytes memory trimmed = new bytes(callData.length - 4);
        for (uint i = 4; i < callData.length; i++) {
            trimmed[i - 4] = callData[i];
        }
        return (bytes4(callData), trimmed);
    }

    function _validateUserOperationHash(bytes32 hash, UserOperation memory userOp) internal view {
        if (IEntryPoint(ENTRYPOINT_V06).getUserOpHash(userOp) != hash) revert InvalidUserOperationHash();
    }
    
    function _validateUserOperationSender(address sender, address account) internal pure {
        if (sender != account) revert InvalidUserOperationSender();
    }
}