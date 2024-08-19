// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PermissionManager} from "../PermissionManager.sol";
import {ICoinbaseSmartWallet} from "../interfaces/ICoinbaseSmartWallet.sol";
import {IMagicSpend} from "../interfaces/IMagicSpend.sol";
import {IPermissionCallable} from "../interfaces/IPermissionCallable.sol";
import {IPermissionContract} from "../interfaces/IPermissionContract.sol";
import {Bytes} from "./Bytes.sol";
import {UserOperation, UserOperationUtils} from "./UserOperationUtils.sol";

/// @title NativeTokenRecurringAllowance
///
/// @notice Supports spending native token with recurring limits.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
abstract contract NativeTokenRecurringAllowance {
    /// @notice Recurring period time parameters.
    struct RecurringPeriod {
        /// @dev start time of the first cycle (unix seconds)
        uint48 start;
        /// @dev period of the cycle (seconds)
        uint48 duration;
    }

    struct AllowanceCycle {
        /// @dev start time of the last updated cycle (unix seconds)
        uint48 start;
        /// @dev accumulated spend amount for latest cycle
        uint208 spend;
    }

    /// @notice Spend value exceeds max size of uint208
    error SpendValueOverflow();

    /// @notice Spend value exceeds permission's spending limit
    error ExceededRecurringAllowance();

    /// @notice Recurring period duration must be greater than zero
    error ZeroRecurringPeriodDuration();

    /// @notice Already initialized recurring allowance
    error InitializedRecurringAllowance();

    /// @notice Register native token spend for a permission
    event SpendRegistered(address indexed account, bytes32 indexed permissionHash, uint256 value);

    /// @notice Register native token spend for a permission
    event RecurringAllowanceUpdated(
        address indexed account,
        bytes32 indexed permissionHash,
        uint256 recurringAllowance,
        uint48 recurringPeriodStart,
        uint48 recurringPeriodDuration
    );

    /// @notice Recurring allowance for the permission.
    mapping(address account => mapping(bytes32 permissionHash => uint256)) internal _recurringAllowances;

    /// @notice Recurring period parameters for the permission.
    mapping(address account => mapping(bytes32 permissionHash => RecurringPeriod)) internal _recurringPeriods;

    /// @notice Amount of native token spent in the current cycle for the permission.
    mapping(address account => mapping(bytes32 permissionHash => AllowanceCycle)) internal _latestAllowanceCycles;

    /// @notice Calculate rolling spend for the period.
    ///
    /// @param account The account tied to the permission.
    /// @param permissionHash Hash of the permission.
    ///
    /// @return rollingSpend Value of spend done by this permission in the past period.
    function getCurrentAllowanceCycle(address account, bytes32 permissionHash)
        public
        view
        returns (AllowanceCycle memory)
    {
        RecurringPeriod memory recurringPeriod = _recurringPeriods[account][permissionHash];
        AllowanceCycle memory latestAllowanceCycle = _latestAllowanceCycles[account][permissionHash];
        uint48 currentTimestamp = uint48(block.timestamp);

        if (currentTimestamp < latestAllowanceCycle.start + recurringPeriod.duration) {
            // latest cycle is still current
            return latestAllowanceCycle;
        } else {
            // latest cycle is outdated

            // current period progress is remainder of time since first recurring period mod duration
            uint48 currentRecurringPeriodProgress =
                (currentTimestamp - recurringPeriod.start) % recurringPeriod.duration;

            // cycle start is now - progress with zero spend value
            return AllowanceCycle(currentTimestamp - currentRecurringPeriodProgress, 0);
        }
    }

    /// @notice Assert native token spend on a rolling period.
    ///
    /// @param account Address of the account asserting spend for.
    /// @param permissionHash Hash of the permission.
    /// @param spend Amount of native token being spent.
    function _assertSpend(address account, bytes32 permissionHash, uint256 spend) internal {
        // early return if no value spent
        if (spend == 0) return;

        AllowanceCycle memory allowanceCycle = getCurrentAllowanceCycle(account, permissionHash);

        // check spend value does not exceed max value
        if (spend + uint256(allowanceCycle.spend) > type(uint208).max) revert SpendValueOverflow();

        // check spend value does not exceed rolling allowance
        if (uint208(spend) + allowanceCycle.spend > _recurringAllowances[account][permissionHash]) {
            revert ExceededRecurringAllowance();
        }

        // save new data for latest cycle
        allowanceCycle.spend += uint208(spend);
        _latestAllowanceCycles[account][permissionHash] = allowanceCycle;

        emit SpendRegistered(account, permissionHash, spend);
    }

    function _initializeRecurringAllowance(
        address account,
        bytes32 permissionHash,
        uint256 recurringAllowance,
        uint48 recurringPeriodStart,
        uint48 recurringPeriodDuration
    ) internal {
        // check recurring period duration is non-zero
        if (recurringPeriodDuration == 0) revert ZeroRecurringPeriodDuration();

        // check permission has not already been initialized
        if (_recurringPeriods[account][permissionHash].duration > 0) revert InitializedRecurringAllowance();

        // initialize state
        _recurringAllowances[account][permissionHash] = recurringAllowance;
        _recurringPeriods[account][permissionHash] = RecurringPeriod(recurringPeriodStart, recurringPeriodDuration);

        emit RecurringAllowanceUpdated(
            account, permissionHash, recurringAllowance, recurringPeriodStart, recurringPeriodDuration
        );
    }
}
