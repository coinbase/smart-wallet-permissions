// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserOperationUtils} from "../../utils/UserOperationUtils.sol";

abstract contract RollingNativeTokenSpendLimit is UserOperationUtils {
    /// @notice Spend of native token at a timestamp
    ///
    /// @dev Only supports individual spend value <= 1e65 to support packing and realistic cases
    struct Spend {
        uint40 timestamp;
        uint216 value;
    }

    /// @notice Spend value exceeds max size of uint216
    error SpendValueOverflow();

    /// @notice Spend value exceeds permission's spending limit
    error ExceededSpendingLimit();

    /// @notice Spend in user operation not registered at end of execution.
    error MissingAssertSpend();

    /// @notice Register native token spend for a permission
    event SpendRegistered(address indexed account, bytes32 indexed permissionHash, uint256 value);

    /// @notice Count of native token spends per permission per account.
    ///
    /// @dev last mapping key must be account address for 4337 slot access.
    mapping(bytes32 permissionHash => mapping(address account => uint256 count)) private _permissionSpendCount;

    /// @notice All native token spends per permission per account.
    ///
    /// @dev last mapping key must be account address for 4337 slot access.
    mapping(bytes32 permissionHash => mapping(uint256 spendIndex => mapping(address account => Spend spend))) private
        _permissionSpend;

    /// @notice Register a spend of native token for a given permission.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS vector.
    function assertSpend(uint256 spendValue, bytes32 permissionHash, uint256 spendLimit, uint256 spendPeriod)
        external
    {
        // early return if no value spent
        if (spendValue == 0) return;
        // check spend value within 216 bits
        if (spendValue > type(uint216).max) revert SpendValueOverflow();
        // check spend value does not exceed limit for period
        uint256 rollingSpend = _calculateRollingSpend(msg.sender, permissionHash, spendPeriod);
        if (spendValue + rollingSpend > spendLimit) {
            revert ExceededSpendingLimit();
        }
        // add spend to state
        uint256 index = ++_permissionSpendCount[permissionHash][msg.sender];
        _permissionSpend[permissionHash][index][msg.sender] = Spend(uint40(block.timestamp), uint216(spendValue));

        emit SpendRegistered(msg.sender, permissionHash, spendValue);
    }

    /// @notice Assert that a given call is made to assertSpend for the account
    ///
    /// @dev Does not protect against re-entrancy where an external call could trigger an authorized call back to the
    /// account to spend more ETH.
    /// @dev Does not measure or account for ETH spent via gas if a paymaster is not used.
    function _validateAssertSpendCall(
        uint256 spendValue,
        bytes32 permissionHash,
        uint256 spendLimit,
        uint256 spendPeriod,
        Call memory call
    ) internal view {
        bytes memory assertSpendData = abi.encodeWithSelector(
            RollingNativeTokenSpendLimit.assertSpend.selector, spendValue, permissionHash, spendLimit, spendPeriod
        );
        if (call.target != address(this) || keccak256(call.data) != keccak256(assertSpendData)) {
            revert MissingAssertSpend();
        }
    }

    /// @notice Calculate rolling spend for the period
    ///
    /// @param account The account to localize to
    /// @param permissionHash The unique permission to localize to
    /// @param spendPeriod Time in seconds to look back from now for current spend period
    ///
    /// @return rollingSpend Value of spend done by this permission in the past period
    function _calculateRollingSpend(address account, bytes32 permissionHash, uint256 spendPeriod)
        internal
        view
        returns (uint256 rollingSpend)
    {
        uint256 index = _permissionSpendCount[permissionHash][account];
        while (index > 0) {
            Spend memory spend = _permissionSpend[permissionHash][index][account];
            if (block.timestamp - spendPeriod > spend.timestamp) {
                break;
            }
            rollingSpend += spend.value;
            index -= 1;
        }
    }
}
