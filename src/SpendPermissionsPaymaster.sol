// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {SpendPermissions} from "./SpendPermissions.sol";

/// @title SpendPermissionsPaymaster
///
/// @notice A recurring alowance mechanism for native and ERC-20 tokens for Coinbase Smart Wallet.
///
/// @dev Supports withdrawing tokens through direct call or spending gas as an ERC-4337 Paymaster.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract SpendPermissionsPaymaster is SpendPermissions, Ownable2Step, IPaymaster {
    /// @notice Track the amount of native asset available to be withdrawn per user.
    mapping(address user => uint256 amount) internal _withdrawable;

    /// @notice Thrown during validation in the context of ERC4337, when the withdraw request amount is insufficient
    ///         to sponsor the transaction gas.
    ///
    /// @param withdraw The withdraw request amount.
    /// @param maxGasCost The max gas cost required by the Entrypoint.
    error LessThanGasMaxCost(uint256 withdraw, uint256 maxGasCost);

    /// @notice Thrown when the withdraw request `asset` is not ETH (zero address).
    ///
    /// @param asset The requested asset.
    error UnsupportedPaymasterAsset(address asset);

    /// @notice Thrown when trying to withdraw funds but nothing is available.
    error NoExcess();

    /// @notice Thrown when `postOp()` is called a second time with `PostOpMode.postOpReverted`.
    ///
    /// @dev This should only really occur if, for unknown reasons, the transfer of the withdrawable
    ///      funds to the user account failed (i.e. this contract's ETH balance is insufficient or
    ///      the user account refused the funds or ran out of gas on receive).
    error UnexpectedPostOpRevertedMode();

    /// @notice Constructor
    ///
    /// @param initialOwner address of the owner who can manage Entrypoint stake
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @inheritdoc IPaymaster
    function validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 maxGasCost)
        external
        requireSender(entryPoint())
        returns (bytes memory postOpContext, uint256 validationData)
    {
        (SignedPermission memory signedPermission, uint256 withdrawAmount) =
            abi.decode(userOp.paymasterAndData[20:], (SignedPermission, uint256));
        RecurringAllowance memory recurringAllowance = signedPermission.recurringAllowance;

        // require withdraw amount not less than max gas cost
        if (withdrawAmount < maxGasCost) {
            revert LessThanGasMaxCost(withdrawAmount, maxGasCost);
        }

        // require recurring allowance token is ether
        if (recurringAllowance.token != ETHER) {
            revert UnsupportedPaymasterAsset(recurringAllowance.token);
        }

        // require userOp sender is the recurring allowance spender
        if (userOp.sender != recurringAllowance.spender) {
            revert InvalidSender(userOp.sender);
        }

        // apply permit if signature length non-zero
        if (signedPermission.signature.length > 0) {
            permit(signedPermission);
        }

        // check total spend value does not overflow max value
        if (withdrawAmount > type(uint160).max) revert WithdrawValueOverflow(withdrawAmount);

        // use recurring allowance for withdraw amount
        _useRecurringAllowance(recurringAllowance, uint160(withdrawAmount));

        // pull funds from account into paymaster
        _execute({
            account: recurringAllowance.account,
            target: address(this),
            value: withdrawAmount,
            data: abi.encodeWithSelector(this.paymasterDeposit.selector, maxGasCost, userOp.sender)
        });

        postOpContext = abi.encode(maxGasCost, userOp.sender);
        validationData = (uint256(recurringAllowance.end) << 160) | (uint256(recurringAllowance.start) << 208);
        return (postOpContext, validationData);
    }

    /// @notice Deposit native token into the paymaster for gas sponsorship.
    ///
    /// @dev Called within `this.validatePaymasterUserOp` execution.
    /// @dev `this.validatePaymasterUserOp` enforces `msg.value` will always be greater than `entryPointPrefund`.
    ///
    /// @param entryPointPrefund Amount of native token to deposit into the Entrypoint for required prefund.
    /// @param gasExcessRecipient Address to send native token in excess of gas cost to.
    function paymasterDeposit(uint256 entryPointPrefund, address gasExcessRecipient) external payable {
        if (msg.value < entryPointPrefund) revert LessThanGasMaxCost(msg.value, entryPointPrefund);

        // deposit into Entrypoint for required prefund
        SafeTransferLib.safeTransferETH(entryPoint(), entryPointPrefund);

        // transfer withdraw amount exceeding gas cost to account
        uint256 gasExcess = msg.value - entryPointPrefund;
        if (gasExcess > 0) {
            _withdrawable[gasExcessRecipient] += gasExcess;
        }
    }

    /// @notice Allows the sender to withdraw any available funds associated with their account.
    ///
    /// @dev Can be called back during the `UserOperation` execution to sponsor funds for non-gas related
    ///      use cases (e.g., swap or mint).
    function withdrawGasExcess() external {
        uint256 amount = _withdrawable[msg.sender];
        // we could allow 0 value transfers, but prefer to be explicit
        if (amount == 0) revert NoExcess();

        delete _withdrawable[msg.sender];
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    /// @inheritdoc IPaymaster
    function postOp(IPaymaster.PostOpMode mode, bytes calldata context, uint256 actualGasCost)
        external
        requireSender(entryPoint())
    {
        // `PostOpMode.postOpReverted` should never happen.
        // The flow here can only revert if there are > maxWithdrawDenominator
        // withdraws in the same transaction, which should be highly unlikely.
        // If the ETH transfer fails, the entire bundle will revert due an issue in the EntryPoint
        // https://github.com/eth-infinitism/account-abstraction/pull/293
        if (mode == PostOpMode.postOpReverted) {
            revert UnexpectedPostOpRevertedMode();
        }

        (uint256 maxGasCost, address payable account) = abi.decode(context, (uint256, address));

        // Send unused gas to the user accout.
        IEntryPoint(entryPoint()).withdrawTo(account, maxGasCost - actualGasCost);

        // Compute the total remaining funds available for the user accout.
        uint256 withdrawable = _withdrawable[account];

        // Send the all remaining funds to the user accout.
        delete _withdrawable[account];
        if (withdrawable > 0) {
            SafeTransferLib.forceSafeTransferETH(account, withdrawable, SafeTransferLib.GAS_STIPEND_NO_STORAGE_WRITES);
        }
    }

    /// @notice Adds stake to the EntryPoint.
    ///
    /// @dev Reverts if not called by the owner of the contract. Calling this while an unstake
    ///      is pending will first cancel the pending unstake.
    ///
    /// @param amount              The amount to stake in the Entrypoint.
    /// @param unstakeDelaySeconds The duration for which the stake cannot be withdrawn. Must be
    ///                            equal to or greater than the current unstake delay.
    function entryPointAddStake(uint256 amount, uint32 unstakeDelaySeconds) external payable onlyOwner {
        IEntryPoint(entryPoint()).addStake{value: amount}(unstakeDelaySeconds);
    }

    /// @notice Unlocks stake in the EntryPoint.
    ///
    /// @dev Reverts if not called by the owner of the contract.
    function entryPointUnlockStake() external onlyOwner {
        IEntryPoint(entryPoint()).unlockStake();
    }

    /// @notice Withdraws stake from the EntryPoint.
    ///
    /// @dev Reverts if not called by the owner of the contract. Only call this after the unstake delay
    ///      has passed since the last `entryPointUnlockStake` call.
    ///
    /// @param to The beneficiary address.
    function entryPointWithdrawStake(address payable to) external onlyOwner {
        IEntryPoint(entryPoint()).withdrawStake(to);
    }

    /// @notice Returns the canonical ERC-4337 EntryPoint v0.6 contract.
    function entryPoint() public pure returns (address) {
        return 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    }
}
