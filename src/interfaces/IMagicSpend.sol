// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @notice Minimal interface for MagicSpend (https://github.com/coinbase/magic-spend).
interface IMagicSpend {
    /// @notice Signed withdraw request allowing accounts to withdraw funds from this contract.
    struct WithdrawRequest {
        /// @dev The signature associated with this withdraw request.
        bytes signature;
        /// @dev The asset to withdraw.
        address asset;
        /// @dev The requested amount to withdraw.
        uint256 amount;
        /// @dev Unique nonce used to prevent replays.
        uint256 nonce;
        /// @dev The maximum expiry the withdraw request remains valid for.
        uint48 expiry;
    }

    /// @notice Allows the caller to withdraw funds by calling with a valid `withdrawRequest`.
    ///
    /// @param withdrawRequest The withdraw request.
    function withdraw(WithdrawRequest memory withdrawRequest) external;

    /// @notice Allows the sender to withdraw any available funds associated with their account.
    ///
    /// @dev Can be called back during the `UserOperation` execution to sponsor funds for non-gas related
    ///      use cases (e.g., swap or mint).
    function withdrawGasExcess() external;
}
