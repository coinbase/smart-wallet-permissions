// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {PermissionManager} from "../PermissionManager.sol";
import {ICoinbaseSmartWallet} from "../interfaces/ICoinbaseSmartWallet.sol";
import {IMagicSpend} from "../interfaces/IMagicSpend.sol";
import {IPermissionCallable} from "../interfaces/IPermissionCallable.sol";
import {IPermissionContract} from "../interfaces/IPermissionContract.sol";
import {AllowedContract} from "../utils/AllowedContract.sol";
import {BytesLib} from "../utils/BytesLib.sol";
import {NativeTokenRollingAllowance} from "../utils/NativeTokenRollingAllowance.sol";
import {UserOperation, UserOperationLib} from "../utils/UserOperationLib.sol";

/// @title PermissionCallableAllowedContractNativeTokenRecurringAllowance
///
/// @notice Only allow custom external calls with IPermissionCallable.permissionedCall selector.
/// @notice Only allow custom external calls to a single allowed contract.
/// @notice Allow spending native token with recurring allowance.
/// @notice Allow withdrawing native token from MagicSpend both as paymaster and non-paymaster flows.
///
/// @dev Requires prepending initializePermission call on first use.
/// @dev Requires appending assertSpend call on every use.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract PermissionCallableAllowedContractNativeTokenRecurringAllowance is
    IPermissionContract,
    AllowedContract,
    NativeTokenRecurringAllowance
{
    /// @notice MagicSpend withdraw asset is not native token.
    error InvalidWithdrawAsset();

    /// @notice Call to initializePermission not made with correct target, value, or data.
    error InvalidInitializePermissionCall();

    /// @notice Call to assertSpend not made on self or with invalid data.
    error InvalidAssertSpendCall();

    /// @notice PermissionManager this permission contract trusts for paymaster gas spend data.
    PermissionManager public immutable permissionManager;

    /// @param manager Contract address for PermissionManager.
    constructor(address manager) {
        permissionManager = PermissionManager(manager);
    }

    /// @notice Validate the permission to execute a userOp.
    ///
    /// @dev Offchain userOp construction should append assertSpend call to calls array if spending value.
    /// @dev Rolling native token spend accounting does not protect against re-entrancy where an external call could
    ///      trigger an authorized call back to the account to spend more ETH.
    /// @dev Rolling native token spend accounting overestimates spend via gas when a paymaster is not used.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param permissionFields Additional arguments for validation.
    /// @param userOp User operation to validate permission for.
    function validatePermission(bytes32 permissionHash, bytes calldata permissionFields, UserOperation calldata userOp)
        external
        view
    {
        // parse permission fields
        (,,, address allowedContract) = abi.decode(permissionFields, (uint256, uint48, uint48, address));

        // parse user operation call data as `executeBatch` arguments (call array)
        ICoinbaseSmartWallet.Call[] memory calls = abi.decode(userOp.callData[4:], (ICoinbaseSmartWallet.Call[]));
        uint256 callsLen = calls.length;

        // initialize loop accumulators
        uint256 callsSpend = 0;

        // loop over calls to validate native token spend and allowed contracts
        // start index at 1 to ignore first call, enforced by PermissionManager as validation call on itself
        // end index at callsLen - 2 to ignore assertSpend call, enforced after loop as validation call on self
        for (uint256 i = 1; i < callsLen - 1; i++) {
            ICoinbaseSmartWallet.Call memory call = calls[i];
            bytes4 selector = bytes4(call.data);

            if (selector == IPermissionCallable.permissionedCall.selector) {
                // check call target is the allowed contract
                if (call.target != allowedContract) revert UserOperationLib.TargetNotAllowed();
                // assume PermissionManager already prevents account as target
            } else if (selector == IMagicSpend.withdraw.selector) {
                // parse MagicSpend withdraw request
                IMagicSpend.WithdrawRequest memory withdraw =
                    abi.decode(BytesLib.sliceCallArgs(calls[i].data), (IMagicSpend.WithdrawRequest));

                // check withdraw is native token
                if (withdraw.asset != address(0)) revert InvalidWithdrawAsset();
                // do not need to accrue callsSpend because withdrawn value will be spent in other calls
            } else if (selector == IMagicSpend.withdrawGasExcess.selector) {
                // ok
            } else if (selector == IPermissionContract.initializePermission.selector) {
                // prepare initializePermission data
                bytes memory initializePermissionData = abi.encodeWithSelector(
                    IPermissionContract.initializePermission.selector, permissionHash, permissionFields
                );

                // check call is valid initializePermission
                if (!_isExpectedCall(call, address(this), 0, initializePermissionData)) {
                    revert InvalidInitializePermissionCall();
                }
            } else {
                revert UserOperationLib.SelectorNotAllowed();
            }

            // accumulate spend value
            callsSpend += call.value;
        }

        // prepare expected call data for assertSpend
        bytes memory assertSpendData = abi.encodeWithSelector(
            PermissionCallableAllowedContractNativeTokenRecurringAllowance.assertSpend.selector,
            permissionHash,
            callsSpend,
            // gasSpend is prefund required by entrypoint (ignores refund for unused gas)
            UserOperationLib.getRequiredPrefund(userOp),
            // paymaster data is empty or first 20 bytes are contract address
            userOp.paymasterAndData.length == 0 ? address(0) : address(bytes20(userOp.paymasterAndData[:20]))
        );

        // check last call is valid this.assertSpend
        ICoinbaseSmartWallet.Call memory lastCall = calls[callsLen - 1];
        if (lastCall.target != address(this) || keccak256(lastCall.data) != keccak256(assertSpendData)) {
            revert InvalidAssertSpendCall();
        }
    }

    /// @notice Register a spend of native token for a given permission.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS vector.
    /// @dev State read on Manager for adding paymaster gas to total spend must happen in execution phase.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param callsSpend Value of native token spent in calls.
    /// @param gasSpend Value of native token spent by gas.
    /// @param paymaster Paymaster used by user operation.
    function assertSpend(bytes32 permissionHash, uint256 callsSpend, uint256 gasSpend, address paymaster) external {
        uint256 totalSpend = callsSpend;

        // add gas cost if beared by the user
        if (paymaster == address(0) || permissionManager.shouldAddPaymasterGasToTotalSpend(paymaster)) {
            totalSpend += gasSpend;
            // recall MagicSpend enforces withdraw to be native token when used as a paymaster
        }

        // assert native token spend
        _assertSpend(msg.sender, permissionHash, totalSpend);
    }

    function initializePermission(bytes32 permissionHash, bytes calldata permissionFields) external {
        // parse permission fields
        (
            uint256 recurringAllowance,
            uint48 recurringPeriodStart,
            uint48 recurringPeriodDuration,
            address allowedContract
        ) = abi.decode(permissionFields, (uint256, uint48, uint48, address));

        _initializeRecurringAllowance(
            msg.sender, permissionHash, recurringAllowance, recurringPeriodStart, recurringPeriodDuration
        );

        _initializeAllowedContract(msg.sender, permissionHash, allowedContract);
    }
}
