// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {SpendPermissions} from "./SpendPermissions.sol";

/// @title SpendPermissionsSignatures
///
/// @notice A recurring alowance mechanism for native and ERC-20 tokens for Coinbase Smart Wallet.
///
/// @dev Supports withdrawing tokens through direct call or spending gas as an ERC-4337 Paymaster.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract SpendPermissionsSignatures is SpendPermissions {
    /// @notice Signed withdraw request allowing accounts to withdraw funds from this contract.
    struct WithdrawRequest {
        /// @dev Recurring allowance to withdraw using.
        RecurringAllowance recurringAllowance;
        /// @dev Address of the withdraw-receiving entity.
        address recipient;
        /// @dev The requested amount to withdraw.
        uint256 amount;
        /// @dev The maximum expiry the withdraw request remains valid for.
        uint48 expiry;
        /// @dev Unique nonce used to prevent replays.
        uint256 nonce;
        /// @dev The signature associated with this withdraw request.
        bytes signature;
    }

    /// @notice Hash of EIP-712 message type
    bytes32 private constant _WITHDRAW_REQUEST_TYPEHASH = keccak256(
        "WithdrawRequest(RecurringAllowance recurringAllowance,uint256 amount,uint48 expiry,uint256 nonce)RecurringAllowance(address account,address spender,address token,uint48 start,uint48 end,uint48 period,uint160 allowance)"
    );

    /// @dev Mappings keeping track of already used nonces per user to prevent replays of withdraw requests.
    mapping(uint256 nonce => mapping(address spender => bool used)) internal _nonceUsed;

    function getHash(WithdrawRequest memory withdrawRequest) public view returns (bytes32) {
        return _eip712Hash(
            keccak256(
                abi.encode(
                    _WITHDRAW_REQUEST_TYPEHASH,
                    keccak256(abi.encode(_RECURRING_ALLOWANCE_TYPEHASH, withdrawRequest.recurringAllowance)),
                    withdrawRequest.recipient,
                    withdrawRequest.amount,
                    withdrawRequest.expiry,
                    withdrawRequest.nonce
                )
            )
        );
    }

    function withdraw(WithdrawRequest memory withdrawRequest) public {
        // use nonce
        if (_nonceUsed[withdrawRequest.nonce][withdrawRequest.recurringAllowance.spender]) {
            revert();
        }
        _nonceUsed[withdrawRequest.nonce][withdrawRequest.recurringAllowance.spender] = true;

        // check valid signature
        bytes32 hash = getHash(withdrawRequest);
        if (
            !_isValidSignature(
                withdrawRequest.recurringAllowance.spender, getHash(withdrawRequest), withdrawRequest.signature
            )
        ) {
            revert();
        }

        // use recurring allowance
        _useRecurringAllowance(withdrawRequest.recurringAllowance, withdrawRequest.amount);

        // transfer tokens from account
        _transferFrom(
            withdrawRequest.recurringAllowance.account,
            withdrawRequest.recurringAllowance.token,
            withdrawRequest.recipient,
            withdrawRequest.amount
        );
    }
}
