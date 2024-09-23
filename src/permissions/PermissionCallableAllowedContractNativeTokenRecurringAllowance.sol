// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MagicSpend} from "magic-spend/MagicSpend.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {PermissionManager} from "../PermissionManager.sol";
import {IPermissionCallable} from "../interfaces/IPermissionCallable.sol";
import {IPermissionContract} from "../interfaces/IPermissionContract.sol";
import {NativeTokenRecurringAllowance} from "../mixins/NativeTokenRecurringAllowance.sol";
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
    NativeTokenRecurringAllowance
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

    /// @notice Cannot initialize with zero-address.
    error ZeroAddress();

    /// @notice Detected that gas fee is being paid for by user (MagicSpend or no paymaster).
    error GasSponsorshipRequired();

    /// @notice MagicSpend withdraw asset is not native token.
    ///
    /// @param asset Address of asset for MagicSpend withdraw request.
    error InvalidWithdrawAsset(address asset);

    /// @notice Call to useRecurringAllowance not made on self or with invalid data.
    error InvalidUseRecurringAllowanceCall();

    /// @notice Constructor.
    ///
    /// @param permissionManager_ Contract address for PermissionManager.
    /// @param magicSpend_ Contract address for MagicSpend.
    constructor(address permissionManager_, address magicSpend_) {
        if (permissionManager_ == address(0) || magicSpend_ == address(0)) revert ZeroAddress();
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

    /// @notice Validate the permission to execute a userOp.
    ///
    /// @dev Offchain userOp construction should append useRecurringAllowance call to calls array if spending value.
    /// @dev Recurring native token spend accounting does not protect against re-entrancy where an external call could
    ///      trigger an authorized call back to the account to spend more ETH.
    ///
    /// @param account Account of the permission.
    /// @param permissionHash Hash of the permission.
    /// @param permissionValues Permission-specific values for this permission contract.
    /// @param calls Calls to batch execute.
    function validatePermissionedBatch(
        address account,
        bytes32 permissionHash,
        bytes calldata permissionValues,
        CoinbaseSmartWallet.Call[] calldata calls
    ) external {
        (PermissionValues memory values) = abi.decode(permissionValues, (PermissionValues));

        // initialize loop accumulators
        uint256 callsSpend = 0;

        // loop over calls to validate native token spend and allowed contracts
        uint256 callsLen = calls.length;
        for (uint256 i = 0; i < callsLen; i++) {
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

        _useRecurringAllowance({account: account, permissionHash: permissionHash, spend: callsSpend});
    }

    function validatePermission(bytes32 permissionHash, bytes calldata permissionValues, UserOperation calldata userOp)
        external
        view
    {}

    function useRecurringAllowance(bytes32 permissionHash, uint256 spend) external {}
}
