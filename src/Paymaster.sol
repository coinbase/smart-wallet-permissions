// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {RecurringAllowanceManager} from "./RecurringAllowanceManager.sol";

/// @title SpendPermissions
///
/// @notice A recurring alowance mechanism for native and ERC-20 tokens for Coinbase Smart Wallet.
///
/// @dev Supports withdrawing tokens through direct call or spending gas as an ERC-4337 Paymaster.
contract SpendPermissions is RecurringAllowanceManager, Ownable2Step, IPaymaster {
    /// @notice Slot for transient storage lock for paymaster deposits.
    bytes32 private constant DEPOSIT_LOCK_SLOT = 0;

    /// @notice Thrown during validation in the context of ERC4337, when the withdraw request amount is insufficient
    ///         to sponsor the transaction gas.
    ///
    /// @param withdraw The withdraw request amount.
    /// @param maxGasCost The max gas cost required by the Entrypoint.
    error WithdrawLessThanGasMaxCost(uint256 withdraw, uint256 maxGasCost);

    /// @notice Thrown when the withdraw request `asset` is not ETH (zero address).
    ///
    /// @param asset The requested asset.
    error UnsupportedPaymasterAsset(address asset);

    /// @notice Depositing is locked.
    error DepositLocked();

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
        // todo allow passing signature for first-time allowance use
        (bytes memory context, uint256 withdrawAmount) = abi.decode(userOp.paymasterAndData[20:], (bytes, uint256));
        (RecurringAllowance memory recurringAllowance, bytes memory signature) = decodeContext(context);

        // require withdraw amount not less than max gas cost
        if (withdrawAmount < maxGasCost) {
            revert WithdrawLessThanGasMaxCost(withdrawAmount, maxGasCost);
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
        if (signature.length > 0) {
            permit(recurringAllowance, signature);
        }

        // check total spend value does not overflow max value
        if (withdrawAmount > type(uint160).max) revert WithdrawValueOverflow(withdrawAmount);

        // use recurring allowance for withdraw amount
        _useRecurringAllowance(recurringAllowance, uint160(withdrawAmount));

        // pull funds from account into paymaster
        _unlockDeposit();
        CoinbaseSmartWallet(payable(recurringAllowance.account)).execute({
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
    /// @dev `this.validatePaymasterUserOp` enforces `msg.value` will always be greater than `maxGasCost`.
    ///
    /// @param maxGasCost Amount of native token to deposit into the Entrypoint for required prefund.
    /// @param gasExcessRecipient Address to send native token in excess of gas cost to.
    function paymasterDeposit(uint256 maxGasCost, address gasExcessRecipient) external payable {
        // read transient storage to check if deposit has been unlocked and if so re-lock it
        if (!_isDepositUnlocked()) revert DepositLocked();
        else _lockDeposit();

        // deposit into Entrypoint for required prefund
        SafeTransferLib.safeTransferETH(entryPoint(), maxGasCost);

        // transfer withdraw amount exceeding gas cost to account
        uint256 gasExcess = msg.value - maxGasCost;
        if (gasExcess > 0) {
            SafeTransferLib.forceSafeTransferETH(
                gasExcessRecipient, gasExcess, SafeTransferLib.GAS_STIPEND_NO_STORAGE_WRITES
            );
        }
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

    /// @notice Unlock deposits from accounts into the paymaster
    function _unlockDeposit() internal {
        assembly {
            tstore(DEPOSIT_LOCK_SLOT, 1)
        }
    }

    /// @notice Lock deposits from accounts into the paymaster
    function _lockDeposit() internal {
        assembly {
            tstore(DEPOSIT_LOCK_SLOT, 0)
        }
    }

    /// @notice Read if deposits are unlocked from accounts into the paymaster
    ///
    /// @return unlocked true if deposit is unlocked
    function _isDepositUnlocked() internal view returns (bool unlocked) {
        assembly {
            unlocked := tload(DEPOSIT_LOCK_SLOT)
        }
    }
}
