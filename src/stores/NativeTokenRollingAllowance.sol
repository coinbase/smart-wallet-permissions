// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {PermissionManager} from "../PermissionManager.sol";

import {IPermissionCallable} from "../PermissionCallable/IPermissionCallable.sol";
import {IPermissionContract} from "../permissions/IPermissionContract.sol";
import {Bytes} from "../utils/Bytes.sol";
import {ICoinbaseSmartWallet} from "../utils/ICoinbaseSmartWallet.sol";
import {IMagicSpend} from "../utils/IMagicSpend.sol";
import {UserOperation, UserOperationUtils} from "../utils/UserOperationUtils.sol";

/// @title NativeTokenRollingAllowance
///
/// @notice Supports spending native token with rolling limits.
/// @notice Only allow calls to a single allowed contract using IPermissionCallable.permissionedCall selector.
///
/// @dev Called by PermissionManager at end of its validation flow.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract NativeTokenRollingAllowance {
    /// @notice Spend of native token at a specific time.
    struct Spend {
        /// @dev Unix timestamp of the spend.
        uint48 timestamp;
        /// @dev Amount of native token spent, max value <= 1e65.
        uint208 value;
    }

    /// @notice Spend value exceeds max size of uint208
    error SpendValueOverflow();

    /// @notice Spend value exceeds permission's spending limit
    error ExceededSpendingLimit();

    /// @notice Register native token spend for a permission
    event SpendRegistered(address indexed account, bytes32 indexed permissionHash, uint256 value);

    /// @notice All native token spends per account per permission.
    mapping(address account => mapping(bytes32 permissionHash => Spend[] spends)) internal _spends;

    /// @notice PermissionManager this permission contract trusts for paymaster gas spend data.
    PermissionManager public immutable permissionManager;

    constructor(address manager) {
        permissionManager = PermissionManager(manager);
    }

    /// @notice Register a spend of native token for a given permission.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS vector.
    /// @dev State read on Manager for adding paymaster gas to total spend must happen in execution phase.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param spendLimit Value of native token that cannot be exceeded over the rolling period.
    /// @param rollingPeriod Seconds duration for the rolling period.
    /// @param callsSpend Value of native token spent in calls.
    /// @param gasSpend Value of native token spent by gas.
    /// @param paymaster Paymaster used by user operation.
    function assertSpend(
        bytes32 permissionHash,
        uint256 spendLimit,
        uint256 rollingPeriod,
        uint256 callsSpend,
        uint256 gasSpend,
        address paymaster
    ) external {
        uint256 totalSpend = callsSpend;

        // add gas cost if beared by the user
        if (paymaster == address(0) || permissionManager.shouldAddPaymasterGasToTotalSpend(paymaster)) {
            totalSpend += gasSpend;
            // recall MagicSpend enforces withdraw to be native token when used as a paymaster
        }

        // assert native token spend
        _assertSpend(permissionHash, totalSpend, spendLimit, rollingPeriod);
    }

    /// @notice Calculate rolling spend for the period.
    ///
    /// @param account The account tied to the permission.
    /// @param permissionHash Hash of the permission.
    /// @param rollingPeriod Time in seconds to look back from now for current spend period.
    ///
    /// @return rollingSpend Value of spend done by this permission in the past period.
    function calculateRollingSpend(address account, bytes32 permissionHash, uint256 rollingPeriod)
        public
        view
        returns (uint256 rollingSpend)
    {
        uint256 spendsLen = _spends[account][permissionHash].length;

        // loop backwards from most recent to oldest spends
        for (uint256 i = spendsLen; i > 0; i--) {
            Spend memory spend = _spends[account][permissionHash][i - 1];

            // break loop if spend is before our spend period lower bound
            if (spend.timestamp < block.timestamp - rollingPeriod) break;

            // increment rolling spend
            rollingSpend += spend.value;
        }
    }

    /// @notice Assert native token spend on a rolling period.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param totalSpend Amount of native token being spent.
    /// @param rollingPeriod Amount of time in seconds to lookback for rolling spend calculation.
    function _assertSpend(bytes32 permissionHash, uint256 totalSpend, uint256 spendLimit, uint256 rollingPeriod)
        internal
    {
        // early return if no value spent
        if (totalSpend == 0) return;

        // check spend value within max value
        if (totalSpend > type(uint208).max) revert SpendValueOverflow();

        // check spend value does not exceed limit for period
        uint256 rollingSpend = calculateRollingSpend(msg.sender, permissionHash, rollingPeriod);
        if (totalSpend + rollingSpend > spendLimit) revert ExceededSpendingLimit();

        // add spend to state
        _spends[msg.sender][permissionHash].push(Spend(uint48(block.timestamp), uint208(totalSpend)));

        emit SpendRegistered(msg.sender, permissionHash, totalSpend);
    }
}
