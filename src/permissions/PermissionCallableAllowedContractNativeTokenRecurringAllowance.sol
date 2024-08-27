// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MagicSpend} from "magic-spend/MagicSpend.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {PermissionManager} from "../PermissionManager.sol";
import {IPermissionCallable} from "../interfaces/IPermissionCallable.sol";
import {IPermissionContract} from "../interfaces/IPermissionContract.sol";
import {BytesLib} from "../utils/BytesLib.sol";
import {NativeTokenRecurringAllowance} from "../utils/NativeTokenRecurringAllowance.sol";
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
    NativeTokenRecurringAllowance
{
    /// @notice Permission-specific values for this permission contract.
    struct PermissionValues {
        /// @dev Recurring native token allowance value (struct).
        RecurringAllowance recurringAllowance;
        /// @dev Single contract allowed to make custom external calls to.
        address allowedContract;
    }

    /// @notice Sender for intializePermission was not permission manager.
    error InvalidInitializePermissionSender();

    /// @notice MagicSpend withdraw asset is not native token.
    ///
    /// @param asset Address of asset for MagicSpend withdraw request.
    error InvalidWithdrawAsset(address asset);

    /// @notice Call to useRecurringAllowance not made on self or with invalid data.
    error InvalidUseRecurringAllowanceCall();

    /// @notice PermissionManager singleton.
    address public immutable permissionManager;

    /// @notice MagicSpend singleton.
    address public immutable magicSpend;

    /// @notice Constructor.
    ///
    /// @param permissionManager_ Contract address for PermissionManager.
    /// @param magicSpend_ Contract address for MagicSpend.
    constructor(address permissionManager_, address magicSpend_) {
        permissionManager = permissionManager_;
        magicSpend = magicSpend_;
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
                if (call.target != values.allowedContract) revert UserOperationLib.TargetNotAllowed(call.target);
                // assume PermissionManager already prevents account as target
            } else if (selector == MagicSpend.withdraw.selector) {
                // check call target is MagicSpend
                if (call.target != magicSpend) revert UserOperationLib.TargetNotAllowed(call.target);

                // parse MagicSpend withdraw request
                MagicSpend.WithdrawRequest memory withdraw =
                    abi.decode(BytesLib.trimSelector(calls[i].data), (MagicSpend.WithdrawRequest));

                // check withdraw is native token
                if (withdraw.asset != address(0)) revert InvalidWithdrawAsset(withdraw.asset);
                // do not need to accrue callsSpend because withdrawn value will be spent in other calls
            } else if (call.data.length == 0) {
                // only allow direct ETH transfer for debiting paymaster (optional)

                // check call target is paymaster
                if (call.target != UserOperationLib.getPaymaster(userOp.paymasterAndData)) {
                    revert UserOperationLib.TargetNotAllowed(call.target);
                }

                // check call value is less than or equal to max gas cost
                if (call.value > UserOperationLib.getRequiredPrefund(userOp)) {
                    revert UserOperationLib.ValueNotAllowed(call.value);
                }
            } else {
                revert UserOperationLib.SelectorNotAllowed(selector);
            }

            // accumulate spend value
            callsSpend += call.value;
        }

        // prepare expected call data for useRecurringAllowance
        bytes memory useRecurringAllowanceData = abi.encodeWithSelector(
            PermissionCallableAllowedContractNativeTokenRecurringAllowance.useRecurringAllowance.selector,
            permissionHash,
            callsSpend
        );

        // check last call is valid this.useRecurringAllowance
        CoinbaseSmartWallet.Call memory lastCall = calls[callsLen - 1];
        if (lastCall.target != address(this) || !BytesLib.eq(lastCall.data, useRecurringAllowanceData)) {
            revert InvalidUseRecurringAllowanceCall();
        }
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
        if (msg.sender != permissionManager) revert InvalidInitializePermissionSender();

        _initializeRecurringAllowance(account, permissionHash, values.recurringAllowance);
    }

    /// @notice Register a spend of native token for a given permission.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS vector.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param callsSpend Value of native token spent on calls.
    function useRecurringAllowance(bytes32 permissionHash, uint256 callsSpend) external {
        _useRecurringAllowance(msg.sender, permissionHash, callsSpend);
    }
}
