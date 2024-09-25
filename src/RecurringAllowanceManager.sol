// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

/// @title RecurringAllowanceManager
///
/// @notice Allow spending native and ERC20 tokens with recurring allowance.
///
/// @dev Allowance and spend values capped at uint160 ~ 1e48.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-recurringAllowances)
contract RecurringAllowanceManager {
    /// @notice A limited recurringAllowance for an external signer to use an account.
    struct RecurringAllowance {
        /// @dev Smart account this recurringAllowance is valid for.
        address account;
        /// @dev Entity that can spend user funds.
        address spender;
        /// @dev Token address.
        address token;
        /// @dev Start time of the recurring allowance's first cycle (unix seconds).
        uint48 start;
        /// @dev Timestamp this recurringAllowance is valid until (unix seconds).
        uint48 end;
        /// @dev Time duration for resetting spend on a recurring basis (seconds).
        uint48 period;
        /// @dev Maximum allowed value to spend within a recurring cycle
        uint160 allowance;
        /// @dev Optional signature from account owner proving a recurringAllowance is approved.
        bytes approval;
    }

    /// @notice Cycle parameters and spend usage.
    struct CycleUsage {
        /// @dev Start time of the cycle (unix seconds).
        uint48 start;
        /// @dev End time of the cycle (unix seconds).
        uint48 end;
        /// @dev Accumulated spend amount for cycle.
        uint160 spend;
    }

    /// @notice ERC-XXXX
    address public constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Track if recurringAllowances are revoked by accounts.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 hash => mapping(address account => bool revoked)) internal _isRecurringAllowanceRevoked;

    /// @notice Track if recurringAllowances are approved by accounts via transactions.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 hash => mapping(address account => bool approved)) internal _isRecurringAllowanceApproved;

    /// @notice Latest cycle usage for the recurringAllowance.
    mapping(bytes32 hash => mapping(address account => CycleUsage)) internal _lastCycleUsages;

    /// @notice Unauthorized request
    error Unauthorized();

    /// @notice Recurring cycle has not started yet.
    ///
    /// @param start Start time of the recurring allowance (unix seconds).
    error BeforeRecurringAllowanceStart(uint48 start);

    /// @notice Recurring cycle has not started yet.
    ///
    /// @param end Start time of the recurring allowance (unix seconds).
    error AfterRecurringAllowanceEnd(uint48 end);

    /// @notice Withdraw value exceeds max size of uint160.
    ///
    /// @param spend Spend value that triggered overflow.
    error WithdrawValueOverflow(uint256 spend);

    /// @notice Spend value exceeds recurringAllowance's spending limit.
    ///
    /// @param spend Spend value that exceeded allowance.
    /// @param allowance Allowance value that was exceeded.
    error ExceededRecurringAllowance(uint256 spend, uint256 allowance);

    /// @notice RecurringAllowance was approved via transaction.
    ///
    /// @param account The smart contract account the recurringAllowance controls.
    /// @param hash The unique hash representing the recurringAllowance.
    event RecurringAllowanceApproved(
        bytes32 indexed hash, address indexed account, RecurringAllowance recurringAllowance
    );

    /// @notice RecurringAllowance was revoked prematurely by account.
    ///
    /// @param account The smart contract account the recurringAllowance controlled.
    /// @param hash The unique hash representing the recurringAllowance.
    event RecurringAllowanceRevoked(
        bytes32 indexed hash, address indexed account, RecurringAllowance recurringAllowance
    );

    /// @notice Register native token spend for a recurring allowance cycle.
    ///
    /// @param hash Hash of the recurringAllowance.
    /// @param account Account that spent native token via a recurringAllowance.
    /// @param newUsage Start and end of the current cycle with new spend usage (struct).
    event RecurringAllowanceWithdrawn(bytes32 indexed hash, address indexed account, CycleUsage newUsage);

    /// @notice Approve a recurringAllowance to enable its use in user operations.
    ///
    /// @dev Entire RecurringAllowance struct taken as argument for indexers to cache relevant data.
    /// @dev RecurringAllowances can also be validated just-in-time via approval signatures instead of approval storage.
    /// @dev This can be called by anyone after an approval signature has been used for gas optimization.
    ///
    /// @param recurringAllowance Details of the recurringAllowance.
    function approve(RecurringAllowance calldata recurringAllowance) external {
        bytes32 hash = getHash(recurringAllowance);

        // early return if recurringAllowance is already approved
        if (_isRecurringAllowanceApproved[hash][recurringAllowance.account]) {
            return;
        }

        // check sender is recurringAllowance account or approval signature is valid for recurringAllowance account
        if (
            msg.sender != recurringAllowance.account
                && !_isValidApprovalSignature(hash, recurringAllowance.account, recurringAllowance.approval)
        ) {
            revert Unauthorized();
        }

        _isRecurringAllowanceApproved[hash][recurringAllowance.account] = true;
        emit RecurringAllowanceApproved(hash, recurringAllowance.account, recurringAllowance);
    }

    /// @notice Revoke a recurringAllowance to disable its use indefinitely.
    ///
    /// @dev Depending on recurringAllowance contract implementation, recurringAllowances can revoke other
    /// recurringAllowances.
    ///
    /// @param recurringAllowance Details of the recurringAllowance.
    function revoke(RecurringAllowance calldata recurringAllowance) external {
        if (msg.sender != recurringAllowance.account) revert Unauthorized();

        bytes32 hash = getHash(recurringAllowance);

        // early return if recurringAllowance is already revoked
        if (_isRecurringAllowanceRevoked[hash][recurringAllowance.account]) {
            return;
        }

        _isRecurringAllowanceRevoked[hash][recurringAllowance.account] = true;
        emit RecurringAllowanceRevoked(hash, recurringAllowance.account, recurringAllowance);
    }

    /// @notice Withdraw tokens using a recurring allowance.
    ///
    /// @param recurringAllowance Recurring allowance details.
    /// @param spend Amount of token attempting to withdraw (wei).
    function withdraw(RecurringAllowance calldata recurringAllowance, uint160 spend) external {
        // early return if no value spent
        if (spend == 0) return;

        // require sender is spender
        if (msg.sender != recurringAllowance.spender) revert Unauthorized();

        bytes32 hash = getHash(recurringAllowance);

        // require not revoked
        if (_isRecurringAllowanceRevoked[hash][recurringAllowance.account]) revert Unauthorized();

        // require approved
        if (!_isRecurringAllowanceApproved[hash][recurringAllowance.account]) {
            if (!_isValidApprovalSignature(hash, recurringAllowance.account, recurringAllowance.approval)) {
                revert Unauthorized();
            }

            _isRecurringAllowanceApproved[hash][recurringAllowance.account] = true;
            emit RecurringAllowanceApproved(hash, recurringAllowance.account, recurringAllowance);
        }

        // get active cycle start and spend, check if recurring allowance has started
        CycleUsage memory currentCycle = getSpend(recurringAllowance);

        uint256 totalSpend = spend + currentCycle.spend;

        // check total spend value does not exceed max value
        if (totalSpend > type(uint160).max) revert WithdrawValueOverflow(totalSpend);

        // check spend value does not exceed recurring allowance
        if (totalSpend > recurringAllowance.allowance) {
            revert ExceededRecurringAllowance(totalSpend, recurringAllowance.allowance);
        }

        // save new accrued spend for active cycle
        currentCycle.spend = uint160(totalSpend);
        _lastCycleUsages[hash][recurringAllowance.account] = currentCycle;

        emit RecurringAllowanceWithdrawn(
            hash, recurringAllowance.account, CycleUsage(currentCycle.start, currentCycle.end, uint160(spend))
        );

        // send call to Smart Wallet to transfer token
        CoinbaseSmartWallet.Call[] memory calls = new CoinbaseSmartWallet.Call[](1);
        if (recurringAllowance.token == ETHER) {
            calls[0] = CoinbaseSmartWallet.Call({target: recurringAllowance.spender, value: spend, data: hex""});
        } else {
            calls[0] = CoinbaseSmartWallet.Call({
                target: recurringAllowance.token,
                value: 0,
                data: abi.encodeWithSelector(IERC20.transfer.selector, recurringAllowance.spender, spend)
            });
        }
        CoinbaseSmartWallet(payable(recurringAllowance.account)).executeBatch(calls);
    }

    /// @notice Get current cycle usage.
    ///
    /// @dev Reverts if recurring allowance has not started.
    /// @dev Cycle boundaries are fixed intervals of recurringAllowance.start + n * recurringAllowance.period
    ///
    /// @param recurringAllowance RecurringAllowance details for recurring allowance.
    ///
    /// @return currentCycle Currently active cycle with spend usage (struct).
    function getSpend(RecurringAllowance calldata recurringAllowance) public view returns (CycleUsage memory) {
        // check recurring allowance has started
        uint48 currentTimestamp = uint48(block.timestamp);
        if (currentTimestamp < recurringAllowance.start) {
            revert BeforeRecurringAllowanceStart(recurringAllowance.start);
        } else if (currentTimestamp > recurringAllowance.end) {
            revert AfterRecurringAllowanceEnd(recurringAllowance.end);
        }

        bytes32 hash = getHash(recurringAllowance);

        // return last cycle if still active, otherwise compute new active cycle start time with no spend
        CycleUsage memory lastCycleUsage = _lastCycleUsages[hash][recurringAllowance.account];

        // last cycle exists if start, end, and spend are non-zero
        bool lastCycleExists = lastCycleUsage.spend != 0;

        // last cycle still active if current time within [start, end) range, i.e. start-inclusive and end-exclusive
        bool lastCycleStillActive =
            currentTimestamp < uint256(lastCycleUsage.start) + uint256(recurringAllowance.period);

        if (lastCycleExists && lastCycleStillActive) {
            return lastCycleUsage;
        } else {
            // last active cycle does not exist or is outdated, determine current cycle

            // current cycle progress is remainder of time since first recurring cycle mod reset period
            uint48 currentCycleProgress = (currentTimestamp - recurringAllowance.start) % recurringAllowance.period;

            // current cycle start is progress duration before current time
            uint48 start = currentTimestamp - currentCycleProgress;

            // current cycle end will overflow if period is sufficiently large
            bool endOverflow = uint256(start) + uint256(recurringAllowance.period) > type(uint48).max;

            // end is one period after start or maximum uint48 if overflow
            uint48 end = endOverflow ? type(uint48).max : start + recurringAllowance.period;

            return CycleUsage({start: start, end: end, spend: 0});
        }
    }

    /// @notice Hash a RecurringAllowance struct for signing.
    ///
    /// @dev Important that this hash cannot be phished via EIP-191/712 or other method.
    ///
    /// @param recurringAllowance Struct to hash.
    function getHash(RecurringAllowance memory recurringAllowance) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                recurringAllowance.account,
                recurringAllowance.spender,
                recurringAllowance.token,
                recurringAllowance.start,
                recurringAllowance.end,
                recurringAllowance.period,
                recurringAllowance.allowance,
                block.chainid, // prevent cross-chain replay
                address(this) // prevent cross-contract replay
            )
        );
    }

    /// @notice Check if a recurringAllowance approval signature is valid.
    ///
    /// @param account Smart account this recurringAllowance is valid for.
    /// @param hash Hash of the recurringAllowance.
    /// @param approval Signature bytes signed by account owner.
    ///
    /// @return isValid True if approval signature is valid.
    function _isValidApprovalSignature(bytes32 hash, address account, bytes memory approval)
        internal
        view
        returns (bool)
    {
        // early return false if approval is zero-length, otherwise validate via ERC-1271 on account
        return approval.length != 0
            && IERC1271(account).isValidSignature(hash, approval) == IERC1271.isValidSignature.selector;
    }
}
