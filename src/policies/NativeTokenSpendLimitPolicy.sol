// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserOperationUtils} from "../utils/UserOperationUtils.sol";

abstract contract NativeTokenSpendLimitPolicy is UserOperationUtils {
    /// @notice Total value sent in userOp exceeds permission's spending limit
    error ExceededSpendingLimit();

    /// @notice Spend in user operation not registered at end of execution.
    error MissingAssertSpend();
    
    /// @notice Spend in user operation not registered at end of execution.
    error FailedBalanceAssertion();

    /// @notice Register native token spend for a permission
    event SpendRegistered(address indexed account, bytes32 indexed permissionHash, uint256 value);

    /// @notice accumulated spend of native asset per permission per account.
    ///
    /// @dev last mapping key must be account address for 4337 slot access.
    mapping(bytes32 permissionHash => mapping(address account => uint256 spend)) private _permissionSpend;

    /// @notice Register a spend of native token for a given permission.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS risk.
    function assertSpend(uint256 assertBalance, bytes32 permissionHash, uint256 spendValue) external {
        // TODO: uncomment, having an issue with assertion check at simulation-time
        // if (msg.sender.balance != assertBalance) revert FailedBalanceAssertion();
        _permissionSpend[permissionHash][msg.sender] += spendValue;
        emit SpendRegistered(msg.sender, permissionHash, spendValue);
    }
    
    function _validateAllowance(address account, bytes32 permissionHash, uint256 allowance, uint256 attemptSpend) internal view {
        if (_permissionSpend[permissionHash][account] + attemptSpend > allowance) revert ExceededSpendingLimit();
    }

    function _validateAssertCall(bytes32 permissionHash, uint256 attemptSpend, Call[] memory calls) internal view {
        Call memory lastCall = calls[calls.length - 1];
        uint256 expectedBalancePostCalls = msg.sender.balance - attemptSpend;
        bytes memory assertSpendData = abi.encodeWithSelector(NativeTokenSpendLimitPolicy.assertSpend.selector, expectedBalancePostCalls, permissionHash, attemptSpend);
        if (lastCall.target != address(this) || keccak256(lastCall.data) != keccak256(assertSpendData)) {
            revert MissingAssertSpend();
        }
    }
}