// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

import {IPermissionModule} from "./IPermissionModule.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";
import {IMagicCall} from "../utils/IMagicCall.sol";

/// @title OnlySessionKeyCallModule
///
/// @notice Only allow session keys to call a specific function selector on external contracts.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract MagicCallModule is IPermissionModule, UserOperationUtils {
    
    /// @notice Represents a call to make from the account.
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    /// @notice Total value sent in userOp exceeds session's spending limit
    error SpendingLimitExceeded();

    /// @notice UserOperation does not match allowed function selectors.
    error InvalidFunctionCall();
    
    /// @notice Spend in user operation not registered at end of execution.
    error MissingRegisterSpend();
    
    /// @notice Register native token spend for a session
    event RegisterSpend(address indexed account, bytes32 indexed sessionHash, uint256 value);

    /// @notice accumulated spend of native asset per session per account.
    ///
    /// @dev last mapping key must be account address for 4337 slot access.
    mapping(bytes32 sessionHash => mapping(address account => uint256 spend)) internal _sessionSpend;

    /// @notice Register a spend of native token for a given session.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS risk.
    function registerSpend(bytes32 sessionHash, uint256 value) external {
        _sessionSpend[sessionHash][msg.sender] += value;
        emit RegisterSpend(msg.sender, sessionHash, value);
    }

    /// @notice Only allow magicCalls that do not exceed approved native token spend
    ///
    /// @dev Offchain userOp construction must add a call to registerSpend at the end of the calls array
    function validatePermissions(address account, bytes32 hash, bytes32 sessionHash, bytes calldata permissionData, bytes calldata requestData) external view {
        UserOperation memory userOp = abi.decode(requestData, (UserOperation));

        // check userOp matches hash
        if (_hashUserOperation(userOp) != hash) revert InvalidUserOperationHash();
        // check userOp sender matches account
        if (userOp.sender != account) revert InvalidUserOperationSender();
        // check userOp.callData is `executeCalls` (0x34fcd5be)
        (bytes4 selector, bytes memory args) = _splitCallData(userOp.callData);
        if (selector != 0x34fcd5be) revert SelectorNotAllowed();
        // for each call, accumulate attempted spend and check magicCall function selector
        uint256 attemptSpend = 0;
        (Call[] memory calls) = abi.decode(args, (Call[]));
        for (uint256 i; i < calls.length; i++) {
            // accumulate attemptedSpend
            attemptSpend += calls[i].value;
            // check external calls only `magicCall` (0xc4f57a06)
            if (bytes4(calls[i].data) != IMagicCall.magicCall.selector) revert SelectorNotAllowed();
        }
        if (attemptSpend > 0) {
            // attmpted spend cannot exceed approved spend
            (uint256 approvedSpend) = abi.decode(permissionData, (uint256));
            if (_sessionSpend[sessionHash][msg.sender] + attemptSpend > approvedSpend) revert SpendingLimitExceeded();
            // must call this contract with registerSpend(sessionHash, attemptSpend)
            Call memory lastCall = calls[calls.length - 1];
            bytes memory registerSpendData = abi.encodeWithSelector(MagicCallModule.registerSpend.selector, sessionHash, attemptSpend);
            if (lastCall.target != address(this) || keccak256(lastCall.data) != keccak256(registerSpendData)) {
                revert MissingRegisterSpend();
            }
        }   
    }
}