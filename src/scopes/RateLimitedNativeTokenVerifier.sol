// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;


import {IScopeVerifier} from "./IScopeVerifier.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";

/// @title RateLimitedNativeTokenVerifier
///
/// @dev Supports setting spend limits on a rolling basis, e.g. 1 ETH per week.
///      Supports allowlisting and blocklisting function calls.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract RateLimitedNativeTokenVerifier  is IScopeVerifier, UserOperationUtils {

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

    /// @notice recent spends of native asset per account per session, used to enforce rate limiting.
    mapping(address account => mapping(bytes32 sessionId => Spend[])) internal _recentSpends;

    /// @notice verify that the userOp calls match allowlisted contracts+selectors
    function verifyScope(address account, bytes32 hash, bytes32 sessionId, bytes calldata scopeData, bytes calldata dynamicData) external {
        (UserOperation memory userOp) = abi.decode(dynamicData, (UserOperation));

        // check userOp matches hash
        if (_hashUserOperation(userOp) != hash) revert InvalidUserOperation();
        // parse scopeData parameters
        (uint256 spendRateValue, uint256 spendRatePeriod, bool allowlist, FunctionCall[] memory functions) = abi.decode(scopeData, (uint256, uint256, bool, FunctionCall[]));
        // verify function allowlist/blocklist and calculate native token spend in this userOp
        uint256 attemptSpend = _verifyCalls(userOp.callData, allowlist, functions);
        // verify spend limit and save new spend if valid
        _verifySpendLimit(account, sessionId, attemptSpend, spendRateValue, spendRatePeriod);

    }

    /// @notice verify spend limit and save new spend if valid
    function _verifySpendLimit(address account, bytes32 sessionId, uint256 attemptSpend, uint256 spendRateValue, uint256 spendRatePeriod) internal {
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

        /// @dev No guarantee that execution does not fail, so this math can only assume success optimistically.
        ///      This function is public, but DOS is prevented by keying storage by sender.
        recentSpends.push(Spend(uint40(block.timestamp), uint216(attemptSpend)));
    }

    /// @notice verify function allowlist/blocklist and calculate native token spend in this userOp
    function _verifyCalls(bytes memory callData, bool allowlist, FunctionCall[] memory functions) internal pure returns (uint256 attemptSpend) {
        // check function is executeCalls (0x34fcd5be)
        (bytes4 selector, bytes memory args) = _splitCallData(callData);
        if (selector != 0x34fcd5be) revert UnsupportedFunctionSelector();

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
        return attemptSpend;
    }
}