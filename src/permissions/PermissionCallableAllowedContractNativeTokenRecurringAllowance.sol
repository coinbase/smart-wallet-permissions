// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MagicSpend} from "magic-spend/MagicSpend.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {PermissionManager} from "../PermissionManager.sol";
import {IPermissionCallable} from "../interfaces/IPermissionCallable.sol";
import {IPermissionContract} from "../interfaces/IPermissionContract.sol";
import {NativeTokenRecurringAllowance} from "../mixins/NativeTokenRecurringAllowance.sol";
import {RefundPaymaster} from "../mixins/RefundPaymaster.sol";
import {BytesLib} from "../utils/BytesLib.sol";
import {CallErrors} from "../utils/CallErrors.sol";
import {UserOperation, UserOperationLib} from "../utils/UserOperationLib.sol";

/// @title PermissionCallableAllowedContractNativeTokenRecurringAllowance
///
/// @notice Only allow custom external calls with IPermissionCallable.permissionedCall selector.
/// @notice Only allow custom external calls to a single allowed contract.
/// @notice Allow spending native token with recurring allowance.
/// @notice Allow withdrawing native token from MagicSpend for non-paymaster flow.
///
/// @dev Requires appending useRecurringAllowance call on every use.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract PermissionCallableAllowedContractNativeTokenRecurringAllowance is
    IPermissionContract,
    NativeTokenRecurringAllowance,
    RefundPaymaster
{
    /// @notice Permission-specific values for this permission contract.
    struct PermissionValues {
        /// @dev Recurring native token allowance value (struct).
        RecurringAllowance recurringAllowance;
        /// @dev Single contract allowed to make custom external calls to.
        address allowedContract;
    }

    /// @notice PermissionManager singleton.
    address public immutable permissionManager;

    /// @notice MagicSpend singleton.
    address public immutable magicSpend;

    /// @notice Detected that gas fee is being paid for by user (MagicSpend or no paymaster).
    error GasSponsorshipRequired();

    /// @notice MagicSpend withdraw asset is not native token.
    ///
    /// @param asset Address of asset for MagicSpend withdraw request.
    error InvalidWithdrawAsset(address asset);

    /// @notice Constructor.
    ///
    /// @param permissionManager_ Contract address for PermissionManager.
    /// @param magicSpend_ Contract address for MagicSpend.
    constructor(address permissionManager_, address magicSpend_) {
        permissionManager = permissionManager_;
        magicSpend = magicSpend_;
    }

    /// @notice Initialize the permission values.
    ///
    /// @dev Called by permission manager on approval transaction.
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    /// @param permissionValues Permission-specific values for this permission contract.
    function initializePermission(address account, bytes32 permissionHash, bytes calldata permissionValues) external {
        (PermissionValues memory values) = abi.decode(permissionValues, (PermissionValues));

        // check sender is permission manager
        if (msg.sender != permissionManager) revert InvalidInitializePermissionSender(msg.sender);

        _initializeRecurringAllowance(account, permissionHash, values.recurringAllowance);
    }

    /// @notice Register a spend of native token for a given permission.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS vector.
    ///      Users can only impact themselves though because storage for allowances is keyed by account (msg.sender).
    ///
    /// @param permissionHash Hash of the permission.
    /// @param callsSpend Value of native token spent on calls.
    function useRecurringAllowance(bytes32 permissionHash, uint256 callsSpend, bytes32 userOpHash, address paymaster)
        external
        payable
    {
        uint256 paymasterRefund = msg.value;
        _useRecurringAllowance({account: msg.sender, permissionHash: permissionHash, spend: callsSpend + paymasteRefund});
        if (paymasterRefund != 0) {
            _refundPaymaster({paymaster: paymaster, userOpHash: userOpHash, account: msg.sender, value: paymasteRefund});
        }
    }

    /// @notice Validate the permission to execute a userOp.
    ///
    /// @dev Offchain userOp construction should append useRecurringAllowance call to calls array if spending value.
    /// @dev Recurring native token spend accounting does not protect against re-entrancy where an external call could
    ///      trigger an authorized call back to the account to spend more ETH.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param permissionValues Permission-specific values for this permission contract.
    /// @param userOp User operation to validate permission for.
    function validatePermission(bytes32 permissionHash, bytes calldata permissionValues, UserOperation calldata userOp)
        external
        view
    {
        address paymaster = address(bytes20(userOp.paymasterAndData));
        if (paymaster == address(0) || paymaster == magicSpend) revert GasSponsorshipRequired();

        (PermissionValues memory values) = abi.decode(permissionValues, (PermissionValues));

        // parse user operation call data as `executeBatch` arguments (call array)
        CoinbaseSmartWallet.Call[] memory calls = abi.decode(userOp.callData[4:], (CoinbaseSmartWallet.Call[]));
        uint256 callsLen = calls.length;

        // initialize loop accumulators
        uint256 callsSpend = 0;

        // loop over calls to validate native token spend and allowed contracts
        // start index at 1 to ignore beforeCalls call, enforced by PermissionManager as self-call
        // end index at callsLen - 2 to ignore useRecurringAllowance call, enforced after loop as self-call
        for (uint256 i = 1; i < callsLen - 1; i++) {
            CoinbaseSmartWallet.Call memory call = calls[i];
            bytes4 selector = bytes4(call.data);

            if (selector == IPermissionCallable.permissionedCall.selector) {
                // check call target is the allowed contract
                if (call.target != values.allowedContract) revert CallErrors.TargetNotAllowed(call.target);
                // assume PermissionManager already prevents account as target
            } else if (selector == MagicSpend.withdraw.selector) {
                // check call target is MagicSpend
                if (call.target != magicSpend) revert CallErrors.TargetNotAllowed(call.target);

                // parse MagicSpend withdraw request
                MagicSpend.WithdrawRequest memory withdraw =
                    abi.decode(BytesLib.trimSelector(calls[i].data), (MagicSpend.WithdrawRequest));

                // check withdraw is native token
                if (withdraw.asset != address(0)) revert InvalidWithdrawAsset(withdraw.asset);
                // do not need to accrue callsSpend because withdrawn value will be spent in other calls
            } else {
                revert CallErrors.SelectorNotAllowed(selector);
            }

            // accumulate spend value
            callsSpend += call.value;
        }

        // prepare expected call data for useRecurringAllowance
        bytes memory useRecurringAllowanceData = abi.encodeWithSelector(
            PermissionCallableAllowedContractNativeTokenRecurringAllowance.useRecurringAllowance.selector,
            permissionHash,
            callsSpend,
            UserOperationLib.getUserOpHash(userOp),
            address(bytes20(userOp.paymasterAndData)) // paymaster address
        );

        // check last call is valid this.useRecurringAllowance
        CoinbaseSmartWallet.Call memory lastCall = calls[callsLen - 1];
        if (
            lastCall.target != address(this) || !BytesLib.eq(lastCall.data, useRecurringAllowanceData)
                || lastCall.value > UserOperationLib.getRequiredPrefund(userOp)
        ) {
            revert InvalidUseRecurringAllowanceCall();
        }
    }
}
