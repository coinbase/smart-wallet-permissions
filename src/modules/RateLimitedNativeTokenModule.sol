// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPermissionModule} from "./IPermissionModule.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";

/// @title RateLimitedNativeTokenModule
///
/// @dev Supports setting spend limits on a rolling basis, e.g. 1 ETH per week.
///      Supports allowlisting and blocklisting function calls.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract RateLimitedNativeTokenModule  is IPermissionModule, UserOperationUtils {

    /// @notice Represents a call to make from the account.
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }
    
    /// @notice A contract and function selector to allowlist/blocklist.
    struct FunctionCall {
        address target; // address(0) represents all contracts.
        bytes4 selector;
    }

    /// @notice A timestamped native token spend
    struct Spend {
        uint40 timestamp;
        uint216 value; // TODO: reconsider premature packing, but realistically this is still big enough...
    }

    /// @notice Total value sent in userOp exceeds session's spending limit
    error SpendingLimitExceeded();

    /// @notice UserOperation does not match allowed function selectors.
    error InvalidFunctionCall();
    
    /// @notice Spend in user operation not registered at end of execution.
    error MissingRegisterSpend();

    /// @notice recent spends of native asset per account per session, used to enforce rate limiting.
    mapping(address account => mapping(bytes32 sessionId => Spend[])) internal _recentSpends;

    /// @notice verify that the userOp calls match allowlisted contracts+selectors
    function validatePermissions(address account, bytes32 hash, bytes32 sessionId, bytes calldata permissionData, bytes calldata requestData) external view {
        (UserOperation memory userOp) = abi.decode(requestData, (UserOperation));

        // check userOp matches hash
        if (_hashUserOperation(userOp) != hash) revert InvalidUserOperationHash();
        // parse permissionData parameters
        (uint256 spendRateValue, uint256 spendRatePeriod, bool allowlist, FunctionCall[] memory functions) = abi.decode(permissionData, (uint256, uint256, bool, FunctionCall[]));
        // verify function allowlist/blocklist and calculate native token spend in this userOp
        uint256 attemptSpend = _verifyCalls(sessionId, userOp.callData, allowlist, functions);
        // verify spend limit
        _verifySpendLimit(account, sessionId, attemptSpend, spendRateValue, spendRatePeriod);
    }

    /// @notice Register a spend of native token for a given session.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS risk.
    ///      If this is not acceptable, we could create a check that relies on an 'activeSession' per user in TSTORE potentially.
    function registerSpend(bytes32 sessionId, uint256 value) external {
        _recentSpends[msg.sender][sessionId].push(Spend(uint40(block.timestamp), uint216(value)));

    }

    /// @notice verify spend limit and save new spend if valid
    function _verifySpendLimit(address account, bytes32 sessionId, uint256 attemptSpend, uint256 spendRateValue, uint256 spendRatePeriod) internal view {
        // calculate native token spend this period
        uint256 currentPeriodSpend = 0;
        Spend[] storage recentSpends = _recentSpends[account][sessionId];
        uint256 index = recentSpends.length - 1;
        Spend memory spend = recentSpends[index];
        // while a Spend exists and is within the period, e.g. 1 week
        while (index > 0 && block.timestamp - spend.timestamp > spendRatePeriod) {
            currentPeriodSpend += spend.value;
            index -= 1;
            spend = recentSpends[index];
        }
        // check attemptSpend will not push currentPeriodSpend above spendRateValue
        if (attemptSpend + currentPeriodSpend > spendRateValue) revert SpendingLimitExceeded();
    }

    /// @notice verify function allowlist/blocklist and calculate native token spend in this userOp
    function _verifyCalls(bytes32 sessionId, bytes memory callData, bool allowlist, FunctionCall[] memory functions) internal view returns (uint256 attemptSpend) {
        // check function is executeCalls (0x34fcd5be)
        (bytes4 selector, bytes memory args) = _splitCallData(callData);
        if (selector != 0x34fcd5be) revert SelectorNotAllowed();

        (Call[] memory calls) = abi.decode(args, (Call[]));
        // for each call, accumulate attempted spend and check function allowlist/blocklist conditions
        for (uint256 i; i < calls.length; i++) {
            // accumulate attemptedSpend
            attemptSpend += calls[i].value;
            // check allowlist/blocklist conditions
            (bytes4 callSelector,) = _splitCallData(calls[i].data);
            for (uint j; i < functions.length; j++) {
                bool selectorMatch = callSelector == functions[i].selector;
                bool contractMatch = functions[i].target == address(0) || functions[i].target == calls[i].target;
                // function does not match, check next function
                if (!contractMatch || !selectorMatch) {
                    continue;
                // function matches and is allowlist mechanism, break inner loop and move on to next call
                } else if (allowlist) {
                    break;
                // function matches and is blocklist mechanism, revert
                } else {
                    revert InvalidFunctionCall();
                }
            }
        }
        if (attemptSpend > 0) {
            Call memory lastCall = calls[calls.length - 1];
            bytes memory registerSpendData = abi.encodeWithSelector(RateLimitedNativeTokenModule.registerSpend.selector, sessionId, attemptSpend);
            if (lastCall.target != address(this) || keccak256(lastCall.data) != keccak256(registerSpendData)) {
                revert MissingRegisterSpend();
            }
        }
        return attemptSpend;
    }
}