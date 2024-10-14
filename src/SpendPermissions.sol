// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {EIP712} from "solady/utils/EIP712.sol";

/// @title SpendPermissions
///
/// @notice Allow spending native and ERC20 tokens with a recurring allowance.
///
/// @dev Allowance and spend values capped at uint160 ~ 1e48.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract SpendPermissions is EIP712 {
    /// @notice A recurring allowance for an external spender to withdraw an account's tokens.
    struct RecurringAllowance {
        /// @dev Smart account this recurring allowance is valid for.
        address account;
        /// @dev Entity that can spend user funds.
        address spender;
        /// @dev Token address (ERC-7528 ether address or ERC-20 contract).
        address token;
        /// @dev Timestamp this recurring allowance is valid after (unix seconds).
        uint48 start;
        /// @dev Timestamp this recurring allowance is valid until (unix seconds).
        uint48 end;
        /// @dev Time duration for resetting used allowance on a recurring basis (seconds).
        uint48 period;
        /// @dev Maximum allowed value to spend within a recurring cycle.
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

    bytes32 constant MESSAGE_TYPEHASH = keccak256(
        "RecurringAllowance(address account,address spender,address token,uint48 start,uint48 end,uint48 period,uint160 allowance)"
    );

    /// @notice ERC-7528 address convention for ether (https://eips.ethereum.org/EIPS/eip-7528).
    address public constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Recurring allowance is revoked.
    mapping(bytes32 hash => mapping(address account => bool revoked)) internal _isRevoked;

    /// @notice Recurring allowance is approved.
    mapping(bytes32 hash => mapping(address account => bool approved)) internal _isApproved;

    /// @notice Last updated cycle for a recurring allowance.
    mapping(bytes32 hash => mapping(address account => CycleUsage)) internal _lastUpdatedCycle;

    /// @notice Invalid sender for the external call.
    ///
    /// @param sender Expected sender to be valid.
    error InvalidSender(address sender);

    /// @notice Unauthorized recurring allowance.
    error UnauthorizedRecurringAllowance();

    /// @notice Recurring cycle has not started yet.
    ///
    /// @param start Timestamp this recurring allowance is valid after (unix seconds).
    error BeforeRecurringAllowanceStart(uint48 start);

    /// @notice Recurring cycle has not started yet.
    ///
    /// @param end Timestamp this recurring allowance is valid until (unix seconds).
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
    /// @param hash The unique hash representing the recurring allowance.
    /// @param account The smart contract account the recurring allowance controls.
    /// @param recurringAllowance Details of the recurring allowance.
    event RecurringAllowanceApproved(
        bytes32 indexed hash, address indexed account, RecurringAllowance recurringAllowance
    );

    /// @notice RecurringAllowance was revoked prematurely by account.
    ///
    /// @param hash The unique hash representing the recurring allowance.
    /// @param account The smart contract account the recurring allowance controlled.
    /// @param recurringAllowance Details of the recurring allowance.
    event RecurringAllowanceRevoked(
        bytes32 indexed hash, address indexed account, RecurringAllowance recurringAllowance
    );

    /// @notice Register native token spend for a recurring allowance cycle.
    ///
    /// @param hash Hash of the recurring allowance.
    /// @param account Account that spent native token via a recurring allowance.
    /// @param token Account that spent native token via a recurring allowance.
    /// @param newUsage Start and end of the current cycle with new spend usage (struct).
    event RecurringAllowanceWithdrawn(
        bytes32 indexed hash, address indexed account, address indexed token, CycleUsage newUsage
    );

    /// @notice Require a specific sender for an external call,
    ///
    /// @param sender Expected sender for call to be valid.
    modifier requireSender(address sender) {
        if (msg.sender != sender) revert InvalidSender(sender);
        _;
    }

    /// @notice Approve a recurring allowance via a direct call from the account.
    ///
    /// @dev Prevent phishing approvals by rejecting simulated transactions with the approval event.
    ///
    /// @param recurringAllowance Details of the recurring allowance.
    function approve(RecurringAllowance calldata recurringAllowance)
        external
        requireSender(recurringAllowance.account)
    {
        _approve(recurringAllowance);
    }

    /// @notice Revoke a recurring allowance to disable its use indefinitely.
    ///
    /// @param recurringAllowance Details of the recurring allowance.
    function revoke(RecurringAllowance calldata recurringAllowance)
        external
        requireSender(recurringAllowance.account)
    {
        bytes32 hash = getHash(recurringAllowance);
        _isRevoked[hash][recurringAllowance.account] = true;
        emit RecurringAllowanceRevoked(hash, recurringAllowance.account, recurringAllowance);
    }

    /// @notice Approve a recurring allowance via a signature from the account.
    ///
    /// @param recurringAllowance Details of the recurring allowance.
    /// @param signature Signed approval from the user.
    function permit(RecurringAllowance memory recurringAllowance, bytes memory signature) public {
        // validate signature over recurring allowance data
        if (
            IERC1271(recurringAllowance.account).isValidSignature(getHash(recurringAllowance), signature)
                != IERC1271.isValidSignature.selector
        ) {
            revert UnauthorizedRecurringAllowance();
        }

        _approve(recurringAllowance);
    }

    /// @notice Withdraw tokens using a recurring allowance.
    ///
    /// @param recurringAllowance Details of the recurring allowance.
    /// @param recipient Address to withdraw tokens to.
    /// @param value Amount of token attempting to withdraw (wei).
    function withdraw(RecurringAllowance memory recurringAllowance, address recipient, uint160 value)
        public
        requireSender(recurringAllowance.spender)
    {
        _useRecurringAllowance(recurringAllowance, value);
        _transferFrom(recurringAllowance.account, recurringAllowance.token, recipient, value);
    }

    /// @notice Hash a RecurringAllowance struct for signing in accordance with EIP-191/712.
    ///
    /// @param recurringAllowance Details of the recurring allowance.
    ///
    /// @return hash Hash of the recurring allowance.
    function getHash(RecurringAllowance memory recurringAllowance) public view returns (bytes32) {
        return _hashTypedData(keccak256(abi.encode(MESSAGE_TYPEHASH, recurringAllowance)));
    }

    /// @notice Return if recurring allowance is authorized i.e. approved and not revoked.
    ///
    /// @param recurringAllowance Details of the recurring allowance.
    ///
    /// @return authorized True if recurring allowance is approved and not revoked.
    function isAuthorized(RecurringAllowance memory recurringAllowance) public view returns (bool) {
        bytes32 hash = getHash(recurringAllowance);
        return !_isRevoked[hash][recurringAllowance.account] && _isApproved[hash][recurringAllowance.account];
    }

    /// @notice Get current cycle usage.
    ///
    /// @dev Reverts if recurring allowance has not started or has already ended.
    /// @dev Cycle boundaries are at fixed intervals of [start + n * period, start + (n + 1) * period - 1].
    ///
    /// @param recurringAllowance Details of the recurring allowance.
    ///
    /// @return currentCycle Currently active cycle with spend usage (struct).
    function getCurrentCycle(RecurringAllowance memory recurringAllowance) public view returns (CycleUsage memory) {
        // check current timestamp is within recurring allowance time range
        uint48 currentTimestamp = uint48(block.timestamp);
        if (currentTimestamp < recurringAllowance.start) {
            revert BeforeRecurringAllowanceStart(recurringAllowance.start);
        } else if (currentTimestamp > recurringAllowance.end) {
            revert AfterRecurringAllowanceEnd(recurringAllowance.end);
        }

        // return last cycle if still active, otherwise compute new active cycle start time with no spend
        CycleUsage memory lastUpdatedCycle = _lastUpdatedCycle[getHash(recurringAllowance)][recurringAllowance.account];

        // last cycle exists if spend is non-zero
        bool lastCycleExists = lastUpdatedCycle.spend != 0;

        // last cycle still active if current timestamp within [start, end - 1] range.
        bool lastCycleStillActive =
            currentTimestamp < uint256(lastUpdatedCycle.start) + uint256(recurringAllowance.period);

        if (lastCycleExists && lastCycleStillActive) {
            return lastUpdatedCycle;
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
    /// @param recurringAllowance Details of the recurring allowance.
    function _approve(RecurringAllowance memory recurringAllowance) internal {
        bytes32 hash = getHash(recurringAllowance);
        _isApproved[hash][recurringAllowance.account] = true;
        emit RecurringAllowanceApproved(hash, recurringAllowance.account, recurringAllowance);
    }

    /// @notice Use a recurring allowance.
    ///
    /// @param recurringAllowance Details of the recurring allowance.
    /// @param value Amount of token attempting to withdraw (wei).
    function _useRecurringAllowance(RecurringAllowance memory recurringAllowance, uint256 value) internal {
        // early return if no value spent
        if (value == 0) return;

        // require recurring allowance is approved and not revoked
        if (!isAuthorized(recurringAllowance)) revert UnauthorizedRecurringAllowance();

        CycleUsage memory currentCycle = getCurrentCycle(recurringAllowance);
        uint256 totalSpend = value + uint256(currentCycle.spend);

        // check total spend value does not overflow max value
        if (totalSpend > type(uint160).max) revert WithdrawValueOverflow(totalSpend);

        // check total spend value does not exceed recurring allowance
        if (totalSpend > recurringAllowance.allowance) {
            revert ExceededRecurringAllowance(totalSpend, recurringAllowance.allowance);
        }

        bytes32 hash = getHash(recurringAllowance);

        // save new withdraw for active cycle
        currentCycle.spend = uint160(totalSpend);
        _lastUpdatedCycle[hash][recurringAllowance.account] = currentCycle;
        emit RecurringAllowanceWithdrawn(
            hash,
            recurringAllowance.account,
            recurringAllowance.token,
            CycleUsage(currentCycle.start, currentCycle.end, uint160(value))
        );
    }

    /// @notice Transfer assets from an account to a recipient.
    ///
    /// @param account Address of the user account.
    /// @param token Address of the token contract.
    /// @param recipient Address of the token recipient.
    /// @param value Amount of tokens to transfer.
    function _transferFrom(address account, address token, address recipient, uint256 value) internal {
        // transfer tokens from account to recipient
        if (token == ETHER) {
            _execute({account: account, target: recipient, value: value, data: hex""});
        } else {
            _execute({
                account: account,
                target: token,
                value: 0,
                data: abi.encodeWithSelector(IERC20.transfer.selector, recipient, value)
            });
        }
    }

    /// @notice Execute a single call on an account.
    ///
    /// @param account Address of the user account.
    /// @param target Address of the target contract.
    /// @param value Amount of native token to send in call.
    /// @param data Bytes data to send in call.
    function _execute(address account, address target, uint256 value, bytes memory data) internal virtual {
        CoinbaseSmartWallet(payable(account)).execute({target: target, value: value, data: data});
    }

    /// @notice Return EIP712 domain name and version.
    ///
    /// @return name Name string for the EIP712 domain.
    /// @return version Version string for the EIP712 domain.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "SpendPermissions";
        version = "1";
    }
}
