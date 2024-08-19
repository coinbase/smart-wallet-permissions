// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title NativeTokenRecurringAllowance
///
/// @notice Supports spending native token with recurring limits.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
abstract contract NativeTokenRecurringAllowance {
    /// @notice Recurring cycle parameters.
    struct RecurringCycle {
        /// @dev start time of the first cycle (unix seconds)
        uint48 start;
        /// @dev period of the cycle (seconds)
        uint48 duration;
    }

    /// @notice Active cycle parameters.
    struct ActiveCycle {
        /// @dev start time of the last updated cycle (unix seconds)
        uint48 start;
        /// @dev accumulated spend amount for latest cycle
        uint208 spend;
    }

    /// @notice Recurring allowance for the permission.
    mapping(address account => mapping(bytes32 permissionHash => uint256)) internal _recurringAllowances;

    /// @notice Recurring cycle parameters for the permission.
    mapping(address account => mapping(bytes32 permissionHash => RecurringCycle)) internal _recurringCycles;

    /// @notice Latest active cycle for the permission.
    mapping(address account => mapping(bytes32 permissionHash => ActiveCycle)) internal _lastActiveCycles;

    /// @notice Spend value exceeds max size of uint208
    error SpendValueOverflow();

    /// @notice Spend value exceeds permission's spending limit
    error ExceededRecurringAllowance();

    /// @notice Recurring cycle duration must be greater than zero
    error ZeroRecurringCycleDuration();

    /// @notice Already initialized recurring allowance
    error InitializedRecurringAllowance();

    /// @notice Register native token spend for a recurring allowance cycle.
    ///
    /// @param account Account that spent native token via a permission.
    /// @param permissionHash Hash of the permission.
    /// @param cycleStart Start time of the cycle this spend was used on (unix seconds).
    /// @param spendValue Amount of native token spent (wei).
    event RecurringAllowanceUsed(
        address indexed account, bytes32 indexed permissionHash, uint48 cycleStart, uint256 spendValue
    );

    /// @notice Register native token spend for a permission
    event RecurringAllowanceInitialized(
        address indexed account,
        bytes32 indexed permissionHash,
        uint256 recurringAllowance,
        uint48 recurringCycleStart,
        uint48 recurringCycleDuration
    );

    /// @notice Get recurring allowance for a permission.
    ///
    /// @param account The account tied to the permission.
    /// @param permissionHash Hash of the permission.
    ///
    /// @return recurringAllowance Spendable allowance on a recurring basis (wei).
    /// @return recurringCycleStart Start of the first recurring cycle (unix seconds).
    /// @return recurringCycleDuration Duration of the recurring cycles (seconds).
    function getRecurringAllowance(address account, bytes32 permissionHash)
        public
        view
        returns (uint256 recurringAllowance, uint48 recurringCycleStart, uint48 recurringCycleDuration)
    {
        RecurringCycle memory recurringCycle = _recurringCycles[account][permissionHash];
        recurringAllowance = _recurringAllowances[account][permissionHash];
        return (recurringAllowance, recurringCycle.start, recurringCycle.duration);
    }

    /// @notice Get the currently active cycle for a permission.
    ///
    /// @param account The account tied to the permission.
    /// @param permissionHash Hash of the permission.
    ///
    /// @return cycleStart Start time of the current cycle (unix seconds).
    /// @return cycleSpend Value spent in the current cycle (wei).
    function getActiveCycle(address account, bytes32 permissionHash)
        public
        view
        returns (uint48 cycleStart, uint256 cycleSpend)
    {
        RecurringCycle memory recurringCycle = _recurringCycles[account][permissionHash];
        ActiveCycle memory lastActiveCycle = _lastActiveCycles[account][permissionHash];
        uint48 currentTimestamp = uint48(block.timestamp);

        if (currentTimestamp < lastActiveCycle.start + recurringCycle.duration) {
            // last active cycle is still active
            return (lastActiveCycle.start, uint208(lastActiveCycle.spend));
        } else {
            // last active cycle is outdated

            // current cycle progress is remainder of time since first recurring cycle mod duration
            uint48 currentRecurringCycleProgress = (currentTimestamp - recurringCycle.start) % recurringCycle.duration;

            // cycle start is progress duration in the past and spend value is zero
            return (currentTimestamp - currentRecurringCycleProgress, 0);
        }
    }

    /// @notice Assert native token spend for a permission.
    ///
    /// @param account Address of the account asserting spend for.
    /// @param permissionHash Hash of the permission.
    /// @param spend Amount of native token being spent.
    function _assertNativeTokenSpend(address account, bytes32 permissionHash, uint256 spend) internal {
        // early return if no value spent
        if (spend == 0) return;

        (uint48 cycleStart, uint256 cycleSpend) = getActiveCycle(account, permissionHash);

        // check spend value does not exceed max value
        if (spend + cycleSpend > type(uint208).max) revert SpendValueOverflow();

        // check spend value does not exceed rolling allowance
        if (spend + cycleSpend > _recurringAllowances[account][permissionHash]) {
            revert ExceededRecurringAllowance();
        }

        // save new data for latest cycle
        cycleSpend += spend;
        _lastActiveCycles[account][permissionHash] = ActiveCycle(cycleStart, uint208(cycleSpend));

        emit RecurringAllowanceUsed(account, permissionHash, cycleStart, spend);
    }

    /// @notice Initialize the native token recurring allowance for a permission.
    ///
    /// @param account Account allowed to make external calls.
    /// @param permissionHash Hash of the permission.
    /// @param recurringAllowance Spendable allowance on a recurring basis (wei).
    /// @param recurringCycleStart Start of the first recurring cycle (unix seconds).
    /// @param recurringCycleDuration Duration of the recurring cycles (unix seconds).
    function _initializeNativeTokenRecurringAllowance(
        address account,
        bytes32 permissionHash,
        uint256 recurringAllowance,
        uint48 recurringCycleStart,
        uint48 recurringCycleDuration
    ) internal {
        // check recurring cycle duration is non-zero
        if (recurringCycleDuration == 0) revert ZeroRecurringCycleDuration();

        // check permission has not already been initialized
        if (_recurringCycles[account][permissionHash].duration > 0) revert InitializedRecurringAllowance();

        // initialize state
        _recurringAllowances[account][permissionHash] = recurringAllowance;
        _recurringCycles[account][permissionHash] = RecurringCycle(recurringCycleStart, recurringCycleDuration);

        emit RecurringAllowanceInitialized(
            account, permissionHash, recurringAllowance, recurringCycleStart, recurringCycleDuration
        );
    }
}
