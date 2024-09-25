// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

/// @title RecurringAllowanceManager
///
/// @notice Allow spending native and ERC20 tokens with a recurring allowance.
///
/// @dev Allowance and spend values capped at uint160 ~ 1e48.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract RecurringAllowanceManager {
    /// @notice A recurring allowance for an external spender to withdraw an account's tokens.
    struct RecurringAllowance {
        /// @dev Smart account this recurring allowance is valid for.
        address account;
        /// @dev Entity that can spend user funds.
        address spender;
        /// @dev Token address.
        address token;
        /// @dev Timestamp this recurring allowance is valid after (unix seconds).
        uint48 start;
        /// @dev Timestamp this recurring allowance is valid until (unix seconds).
        uint48 end;
        /// @dev Time duration for resetting spend on a recurring basis (seconds).
        uint48 period;
        /// @dev Maximum allowed value to spend within a recurring cycle
        uint160 allowance;
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
    mapping(bytes32 hash => mapping(address account => bool revoked)) internal _isRecurringAllowanceRevoked;

    /// @notice Track if recurringAllowances are approved by accounts via transactions.
    mapping(bytes32 hash => mapping(address account => bool approved)) internal _isRecurringAllowanceApproved;

    /// @notice Latest cycle usage for the recurringAllowance.
    mapping(bytes32 hash => mapping(address account => CycleUsage)) internal _lastCycleUsages;

    /// @notice Invalid sender for the external call.
    ///
    /// @param sender Expected sender to be valid.
    error InvalidSender(address sender);

    /// @notice Unauthorized recurring allowance.
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
    /// @param value Spend value that triggered overflow.
    error WithdrawValueOverflow(uint256 value);

    /// @notice Spend value exceeds recurring allowance.
    ///
    /// @param value Spend value that exceeded allowance.
    /// @param allowance Allowance value that was exceeded.
    error ExceededRecurringAllowance(uint256 value, uint256 allowance);

    /// @notice RecurringAllowance was approved via transaction.
    ///
    /// @param hash The unique hash representing the recurringAllowance.
    /// @param account The smart contract account the recurringAllowance controls.
    /// @param recurringAllowance Details of the recurringAllowance.
    event RecurringAllowanceApproved(
        bytes32 indexed hash, address indexed account, RecurringAllowance recurringAllowance
    );

    /// @notice RecurringAllowance was revoked prematurely by account.
    ///
    /// @param hash The unique hash representing the recurringAllowance.
    /// @param account The smart contract account the recurringAllowance controlled.
    /// @param recurringAllowance Details of the recurringAllowance.
    event RecurringAllowanceRevoked(
        bytes32 indexed hash, address indexed account, RecurringAllowance recurringAllowance
    );

    /// @notice Register native token spend for a recurring allowance cycle.
    ///
    /// @param hash Hash of the recurringAllowance.
    /// @param account Account that spent native token via a recurringAllowance.
    /// @param newUsage Start and end of the current cycle with new spend usage (struct).
    event RecurringAllowanceWithdrawn(bytes32 indexed hash, address indexed account, CycleUsage newUsage);

    /// @notice Require a specific sender for an external call,
    ///
    /// @param sender Expected sender for call to be valid.
    modifier requireSender(address sender) {
        if (msg.sender != sender) revert InvalidSender(sender);
        _;
    }

    /// @notice Approve a recurringAllowance via a signature from the account.
    ///
    /// @param recurringAllowance Details of the recurringAllowance.
    /// @param signature Signed hash of the recurring allowance data.
    function permit(RecurringAllowance calldata recurringAllowance, bytes calldata signature) external {
        // validate signature over recurringAllowance data
        if (
            IERC1271(recurringAllowance.account).isValidSignature(getHash(recurringAllowance), signature)
                != IERC1271.isValidSignature.selector
        ) {
            revert Unauthorized();
        }

        _approve(recurringAllowance);
    }

    /// @notice Approve a recurringAllowance via a direct call from the account.
    ///
    /// @dev Prevent phishing approvals by rejecting simulated transactions with the approval event.
    ///
    /// @param recurringAllowance Details of the recurringAllowance.
    function approve(RecurringAllowance calldata recurringAllowance)
        external
        requireSender(recurringAllowance.account)
    {
        _approve(recurringAllowance);
    }

    /// @notice Revoke a recurringAllowance to disable its use indefinitely.
    ///
    /// @param recurringAllowance Details of the recurringAllowance.
    function revoke(RecurringAllowance calldata recurringAllowance)
        external
        requireSender(recurringAllowance.account)
    {
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
    /// @param recurringAllowance Details of the recurringAllowance.
    /// @param value Amount of token attempting to withdraw (wei).
    function withdraw(RecurringAllowance calldata recurringAllowance, uint160 value)
        external
        requireSender(recurringAllowance.spender)
    {
        // early return if no value spent
        if (value == 0) return;

        // require recurring allowance is approved and not revoked
        if (!isAuthorized(recurringAllowance)) revert Unauthorized();

        // get active cycle start and spend, check if recurring allowance has started
        CycleUsage memory currentCycle = getCurrentCycle(recurringAllowance);

        // check total spend value does not overflow max value
        uint256 totalSpend = value + currentCycle.spend;
        if (totalSpend > type(uint160).max) revert WithdrawValueOverflow(totalSpend);

        // check total spend value does not exceed recurring allowance
        if (totalSpend > recurringAllowance.allowance) {
            revert ExceededRecurringAllowance(totalSpend, recurringAllowance.allowance);
        }

        bytes32 hash = getHash(recurringAllowance);

        // save new accrued spend for active cycle
        currentCycle.spend = uint160(totalSpend);
        _lastCycleUsages[hash][recurringAllowance.account] = currentCycle;
        emit RecurringAllowanceWithdrawn(
            hash, recurringAllowance.account, CycleUsage(currentCycle.start, currentCycle.end, uint160(value))
        );

        // call account to transfer tokens
        _withdraw({
            owner: recurringAllowance.account,
            recipient: recurringAllowance.spender,
            token: recurringAllowance.token,
            value: value
        });
    }

    /// @notice Hash a RecurringAllowance struct for signing.
    ///
    /// @dev Prevent phishing permits by making the hash incompatible with EIP-191/712.
    ///
    /// @param recurringAllowance Details of the recurringAllowance.
    ///
    /// @return hash Hash of the recurring allowance and replay protection parameters.
    function getHash(RecurringAllowance memory recurringAllowance) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                recurringAllowance,
                block.chainid, // prevent cross-chain replay
                address(this) // prevent cross-contract replay
            )
        );
    }

    /// @notice Return if recurring allowance is authorized i.e. approved and not revoked.
    ///
    /// @param recurringAllowance Details of the recurringAllowance.
    ///
    /// @return authorized True if recurring allowance is approved and not revoked.
    function isAuthorized(RecurringAllowance calldata recurringAllowance) public view returns (bool) {
        bytes32 hash = getHash(recurringAllowance);

        return !_isRecurringAllowanceRevoked[hash][recurringAllowance.account]
            && _isRecurringAllowanceApproved[hash][recurringAllowance.account];
    }

    /// @notice Get current cycle usage.
    ///
    /// @dev Reverts if recurring allowance has not started or has already ended.
    /// @dev Cycle boundaries are fixed intervals of recurringAllowance.start + n * recurringAllowance.period.
    ///
    /// @param recurringAllowance Details of the recurringAllowance.
    ///
    /// @return currentCycle Currently active cycle with spend usage (struct).
    function getCurrentCycle(RecurringAllowance calldata recurringAllowance) public view returns (CycleUsage memory) {
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

    /// @notice Approve recurring allowance.
    ///
    /// @param recurringAllowance Details of the recurringAllowance.
    function _approve(RecurringAllowance calldata recurringAllowance) internal {
        bytes32 hash = getHash(recurringAllowance);

        // early return if recurringAllowance is already approved
        if (_isRecurringAllowanceApproved[hash][recurringAllowance.account]) {
            return;
        }

        _isRecurringAllowanceApproved[hash][recurringAllowance.account] = true;
        emit RecurringAllowanceApproved(hash, recurringAllowance.account, recurringAllowance);
    }

    /// @notice Withdraw tokens from account.
    ///
    /// @param owner Account to withdraw tokens from.
    /// @param recipient Account to withdraw tokens to.
    /// @param token Address of token (either ether or ERC20 contract).
    /// @param value Amount of tokens to withdraw (wei).
    function _withdraw(address owner, address recipient, address token, uint256 value) internal virtual {
        CoinbaseSmartWallet account = CoinbaseSmartWallet(payable(owner));

        if (token == ETHER) {
            account.execute({target: recipient, value: value, data: hex""});
        } else {
            account.execute({
                target: token,
                value: 0,
                data: abi.encodeWithSelector(IERC20.transfer.selector, recipient, value)
            });
        }
    }
}
