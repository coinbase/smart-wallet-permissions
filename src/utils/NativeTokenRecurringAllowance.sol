// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title NativeTokenRecurringAllowance
///
/// @notice Allow spending native token with recurring allowance.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
abstract contract NativeTokenRecurringAllowance {
    /// @notice Recurring cycle parameters.
    struct RecurringAllowance {
        /// @dev Start time of the recurring allowance's first cycle (unix seconds).
        uint48 start;
        /// @dev Time duration for resetting spend on a recurring basis (seconds).
        uint48 period;
        /// @dev Maximum allowed value to spend within a recurring cycle
        uint256 allowance;
    }

    /// @notice Active cycle parameters.
    struct ActiveCycle {
        /// @dev Start time of the active cycle (unix seconds).
        uint48 start;
        /// @dev Accumulated spend amount for active cycle.
        uint208 spend;
    }

    /// @notice Packed recurring allowance values (start, period) for the permission.
    mapping(address account => mapping(bytes32 permissionHash => uint256)) internal _packedRecurringAllowanceValues;

    /// @notice Latest active cycle for the permission.
    mapping(address account => mapping(bytes32 permissionHash => ActiveCycle)) internal _lastActiveCycles;

    /// @notice Spend value exceeds max size of uint208.
    error SpendValueOverflow();

    /// @notice Spend value exceeds permission's spending limit.
    error ExceededRecurringAllowance();

    /// @notice Invalid recurring allowance parameters.
    error InvalidRecurringAllowance();

    /// @notice Recurring cycle has not started yet.
    error BeforeRecurringAllowanceStart();

    /// @notice Register native token spend for a permission
    ///
    /// @param account The account tied to the permission.
    /// @param permissionHash Hash of the permission.
    /// @param recurringAllowance Allowed spend per recurring cycle (struct).
    event RecurringAllowanceInitialized(
        address indexed account, bytes32 indexed permissionHash, RecurringAllowance recurringAllowance
    );

    /// @notice Register native token spend for a recurring allowance cycle.
    ///
    /// @param account Account that spent native token via a permission.
    /// @param permissionHash Hash of the permission.
    /// @param cycleStart Start time of the cycle this spend was used on (unix seconds).
    /// @param spend Amount of native token spent (wei).
    event RecurringAllowanceUsed(
        address indexed account, bytes32 indexed permissionHash, uint48 cycleStart, uint256 spend
    );

    /// @notice Get the currently active cycle for a permission.
    ///
    /// @dev Reverts if recurring allowance has not started.
    ///
    /// @param account The account tied to the permission.
    /// @param permissionHash Hash of the permission.
    ///
    /// @return activeCycle Currently active cycle start and spend (struct).
    function getActiveCycle(address account, bytes32 permissionHash)
        public
        view
        returns (ActiveCycle memory activeCycle)
    {
        uint256 packedValues = _packedRecurringAllowanceValues[account][permissionHash];
        (uint48 start, uint48 period) = _unpackRecurringAllowanceValues(packedValues);
        return _getActiveCycle(account, permissionHash, start, period);
    }

    /// @notice Assert native token spend for a permission.
    ///
    /// @dev Initializes state for recurring allowance start and period for first time use.
    ///      Malicious assertSpend calls may attempt to reset the active cycle's spend by manipulating
    ///      the recurring allowance start and period values, but this will revert because we compare against
    ///      initialized state. A potential griefing attack is to phish a user to assertSpend with improper
    ///      recurring allowance params, which would then just brick the permissionHash from working in happy path.
    ///      With no incentive to grief, little time window to do so, and requiring a user to sign to enable the grief,
    ///      this attack is not of concern.
    ///
    /// @param account Address of the account asserting spend for.
    /// @param permissionHash Hash of the permission.
    /// @param recurringAllowance Allowed spend per recurring cycle (struct).
    /// @param spend Amount of native token being spent.
    function _assertNativeTokenSpend(
        address account,
        bytes32 permissionHash,
        RecurringAllowance memory recurringAllowance,
        uint256 spend
    ) internal {
        // early return if no value spent
        if (spend == 0) return;

        // initialize recurring allowance if not already, or check if parameters match previous initialization
        uint256 packedValues = _packedRecurringAllowanceValues[account][permissionHash];
        if (packedValues == 0) {
            // initialize recurring allowance
            _packedRecurringAllowanceValues[account][permissionHash] =
                uint256((recurringAllowance.start) + (uint256(recurringAllowance.period) << 48));
            emit RecurringAllowanceInitialized(account, permissionHash, recurringAllowance);
        } else {
            // check recurring allowance parameters match initialized start and period
            (uint48 start, uint48 period) = _unpackRecurringAllowanceValues(packedValues);
            if (start != recurringAllowance.start && period != recurringAllowance.period) {
                revert InvalidRecurringAllowance();
            }
        }

        // get active cycle start and spend
        ActiveCycle memory activeCycle =
            _getActiveCycle(account, permissionHash, recurringAllowance.start, recurringAllowance.period);

        // check spend value does not exceed max value
        if (spend + activeCycle.spend > type(uint208).max) revert SpendValueOverflow();

        // check spend value does not exceed recurring allowance
        if (spend + activeCycle.spend > recurringAllowance.allowance) revert ExceededRecurringAllowance();

        // save new accrued spend for active cycle
        activeCycle.spend += uint208(spend);
        _lastActiveCycles[account][permissionHash] = activeCycle;

        emit RecurringAllowanceUsed(account, permissionHash, activeCycle.start, spend);
    }

    /// @notice Get currently active cycle start and spend.
    ///
    /// @dev Reverts if recurring allowance has not started.
    /// @dev Cycle boundaries are fixed intervals of recurringAllowance.start + n * recurringAllowance.period
    ///
    /// @param account The account tied to the permission.
    /// @param permissionHash Hash of the permission.
    /// @param recurringAllowanceStart Start time of the recurring allowance's first cycle (unix seconds).
    /// @param recurringAllowancePeriod Time duration for resetting spend on a recurring basis (seconds).
    ///
    /// @return activeCycle Currently active cycle start and spend (struct).
    function _getActiveCycle(
        address account,
        bytes32 permissionHash,
        uint48 recurringAllowanceStart,
        uint48 recurringAllowancePeriod
    ) private view returns (ActiveCycle memory) {
        // check recurring allowance has started
        uint48 currentTimestamp = uint48(block.timestamp);
        if (currentTimestamp < recurringAllowanceStart) {
            revert BeforeRecurringAllowanceStart();
        }

        // return last cycle if still active, otherwise compute new active cycle start time with no spend
        ActiveCycle memory lastActiveCycle = _lastActiveCycles[account][permissionHash];
        if (lastActiveCycle.start > 0 && currentTimestamp < lastActiveCycle.start + recurringAllowancePeriod) {
            // last active cycle is still active
            return lastActiveCycle;
        } else {
            // last active cycle is outdated

            // current cycle progress is remainder of time since first recurring cycle mod reset period
            uint48 currentCycleProgress = (currentTimestamp - recurringAllowanceStart) % recurringAllowancePeriod;

            // cycle start is progress duration in the past and spend value is zero
            return ActiveCycle(currentTimestamp - currentCycleProgress, 0);
        }
    }

    /// @notice Unpack storage for recurring allowance start and period.
    ///
    /// @param packedValues Stored value for packed start and period values.
    ///
    /// @return start Start time of the first recurring cycle (unix seconds).
    /// @return period Time duration for resetting spend on a recurring basis (seconds).
    function _unpackRecurringAllowanceValues(uint256 packedValues) private pure returns (uint48 start, uint48 period) {
        (start, period) = (uint48(packedValues), uint48(packedValues >> 48));
    }
}
