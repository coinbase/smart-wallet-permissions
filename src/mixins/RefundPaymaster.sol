// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title RefundPaymaster
///
/// @notice Refund a paymaster for sponsoring a user operation.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
abstract contract RefundPaymaster {
    /// @notice Call to refundPaymaster not made on self or with invalid data.
    error InvalidRefundPaymasterCall();

    /// @notice Paymaster refund was rejected.
    error PaymasterRejectedRefund();

    /// @notice Refunded a paymaster from users balance.
    ///
    /// @param userOpHash User operation hash the refund took place in.
    /// @param account Address performing the refund.
    /// @param value Amount of native token refunded.
    event PaymasterRefunded(bytes32 indexed userOpHash, address indexed account, uint256 value);

    /// @notice Refund paymaster in native token.
    ///
    /// @dev Native token lockout is prevented by requiring the paymaster to accept the refund.
    ///
    /// @param paymaster Paymaster contract address to refund.
    /// @param userOpHash User operation hash the refund took place in.
    /// @param account Address performing the refund.
    /// @param value Amount of native token refunded.
    function _refundPaymaster(address paymaster, bytes32 userOpHash, address account, uint256 value) internal {
        (bool success,) = paymaster.call{value: value}();
        if (!success) revert PaymasterRejectedRefund();
        emit PaymasterRefunded(userOpHash, account, value);
    }
}
