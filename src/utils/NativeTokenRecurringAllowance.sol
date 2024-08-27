// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title NativeTokenRecurringAllowance
///
/// @notice Allow spending native token with recurring allowance.
///
/// @dev Allowance and spend values capped at uint160 ~ 1e48.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
/// NIT: is this a util? I don't think this and PermissionCallable should be in this folder? 
/// maybe baseContracts or something ? 
abstract contract NativeTokenRecurringAllowance {
    /// @notice Recurring allowance parameters.
    struct RecurringAllowance {
        /// @dev Start time of the recurring allowance's first cycle (unix seconds).
        uint48 start;
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

    /// @notice Packed recurring allowance values (start, period) for the permission.
    mapping(address account => mapping(bytes32 permissionHash => RecurringAllowance)) internal _recurringAllowances;

    /// @notice Latest cycle usage for the permission.
    mapping(address account => mapping(bytes32 permissionHash => CycleUsage)) internal _lastCycleUsages;

    /// @notice Zero recurring allowance value.
    error ZeroRecurringAllowance();

    /// @notice Recurring cycle has not started yet.
    ///
    /// @param start Start time of the recurring allowance (unix seconds).
    error BeforeRecurringAllowanceStart(uint48 start);

    /// @notice Spend value exceeds max size of uint160.
    ///
    /// @param spend Spend value that triggered overflow.
    error SpendValueOverflow(uint256 spend);

    /// @notice Spend value exceeds permission's spending limit.
    ///
    /// @param spend Spend value that exceeded allowance.
    /// @param allowance Allowance value that was exceeded.
    error ExceededRecurringAllowance(uint256 spend, uint256 allowance);

    /// @notice Register native token spend for a permission
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    /// @param recurringAllowance Allowed spend per recurring cycle (struct).
    event RecurringAllowanceInitialized(
        address indexed account, bytes32 indexed permissionHash, RecurringAllowance recurringAllowance
    );

    /// @notice Register native token spend for a recurring allowance cycle.
    ///
    /// @param account Account that spent native token via a permission.
    /// @param permissionHash Hash of the permission.
    /// @param newUsage Start and end of the current cycle with new spend usage (struct).
    event RecurringAllowanceUsed(address indexed account, bytes32 indexed permissionHash, CycleUsage newUsage);

    /// @notice Get recurring allowance values.
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    ///
    /// @return recurringAllowance Allowed spend per recurring cycle (struct).
    function getRecurringAllowance(address account, bytes32 permissionHash)
        public
        view
        returns (RecurringAllowance memory recurringAllowance)
    {
        return _recurringAllowances[account][permissionHash];
    }

    /// @notice Get the usage data for the currently active recurring cycle.
    ///
    /// @dev Reverts if recurring allowance has not started.
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    ///
    /// @return cycleUsage Currently active cycle start and spend (struct).
    function getRecurringAllowanceUsage(address account, bytes32 permissionHash)
        public
        view
        returns (CycleUsage memory cycleUsage)
    {
        RecurringAllowance memory recurringAllowance = _recurringAllowances[account][permissionHash];
        return _getCurrentCycleUsage(account, permissionHash, recurringAllowance);
    }

    /// @notice Initialize the native token recurring allowance for a permission.
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    /// @param recurringAllowance Allowed spend per recurring cycle (struct).
    function _initializeRecurringAllowance(
        address account,
        bytes32 permissionHash,
        RecurringAllowance memory recurringAllowance
    ) internal {
        // check non-zero recurring allowance
        if (recurringAllowance.allowance == 0) revert ZeroRecurringAllowance();

        // initialize recurring allowance if not yet initialized
        RecurringAllowance memory savedRecurringAllowance = _recurringAllowances[account][permissionHash];
        if (savedRecurringAllowance.allowance == 0) {
            _recurringAllowances[account][permissionHash] = recurringAllowance;
            emit RecurringAllowanceInitialized(account, permissionHash, recurringAllowance);
        }
    }

    /// @notice Use recurring allowance and register spend for active cycle.
    ///
    /// @dev Initializes state for recurring allowance start and period for first time use.
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    /// @param spend Amount of native token being spent.
    function _useRecurringAllowance(address account, bytes32 permissionHash, uint256 spend) internal {
        // early return if no value spent
        if (spend == 0) return;

        // check non-zero recurring allowance, i.e. has been initialized
        RecurringAllowance memory recurringAllowance = _recurringAllowances[account][permissionHash];
        if (recurringAllowance.allowance == 0) revert ZeroRecurringAllowance();

        // get active cycle start and spend, check if recurring allowance has started
        CycleUsage memory currentCycle = _getCurrentCycleUsage(account, permissionHash, recurringAllowance);

        uint256 totalSpend = spend + currentCycle.spend;

        // check spend value does not exceed max value
        if (totalSpend > type(uint160).max) revert SpendValueOverflow(totalSpend);

        // check spend value does not exceed recurring allowance
        if (totalSpend > recurringAllowance.allowance) {
            revert ExceededRecurringAllowance(totalSpend, recurringAllowance.allowance);
        }

        // save new accrued spend for active cycle
        currentCycle.spend = uint160(totalSpend);
        _lastCycleUsages[account][permissionHash] = currentCycle;

        emit RecurringAllowanceUsed(
            account, permissionHash, CycleUsage(currentCycle.start, currentCycle.end, uint160(spend))
        );
    }

    /// @notice Get current cycle usage.
    ///
    /// @dev Reverts if recurring allowance has not started.
    /// @dev Cycle boundaries are fixed intervals of recurringAllowance.start + n * recurringAllowance.period
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    /// @param recurringAllowance Allowed spend per recurring cycle (struct).
    ///
    /// @return currentCycle Currently active cycle with spend usage (struct).
    function _getCurrentCycleUsage(
        address account,
        bytes32 permissionHash,
        RecurringAllowance memory recurringAllowance
    ) private view returns (CycleUsage memory) {
        // check recurring allowance has started
        uint48 currentTimestamp = uint48(block.timestamp);
        if (currentTimestamp < recurringAllowance.start) {
            revert BeforeRecurringAllowanceStart(recurringAllowance.start);
        }

        // return last cycle if still active, otherwise compute new active cycle start time with no spend
        CycleUsage memory lastCycleUsage = _lastCycleUsages[account][permissionHash];
        if (lastCycleUsage.start > 0 && currentTimestamp < lastCycleUsage.start + recurringAllowance.period) {
            // last active cycle is still active
            return lastCycleUsage;
        } else {
            // last active cycle is outdated, determine current cycle

            // current cycle progress is remainder of time since first recurring cycle mod reset period
            uint48 currentCycleProgress = (currentTimestamp - recurringAllowance.start) % recurringAllowance.period;

            return CycleUsage(
                currentTimestamp - currentCycleProgress, // start is progress duration before current time
                currentTimestamp - currentCycleProgress + recurringAllowance.period, // end is a period after start
                0 // no tracked spends yet
            );
        }
    }
}
