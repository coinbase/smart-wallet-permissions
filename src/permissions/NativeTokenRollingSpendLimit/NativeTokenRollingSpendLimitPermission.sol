// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MagicSpend} from "magic-spend/MagicSpend.sol";

import {PermissionManager} from "../../PermissionManager.sol";
import {ICoinbaseSmartWallet} from "../../utils/ICoinbaseSmartWallet.sol";
import {UserOperation, UserOperationUtils} from "../../utils/UserOperationUtils.sol";
import {IPermissionContract} from "../IPermissionContract.sol";
import {IPermissionCallable} from "../PermissionCallable/IPermissionCallable.sol";
// import {IMagicSpend} from "../../utils/IMagicSpend.sol";

/// @title NativeTokenRollingSpendLimitPermission
///
/// @notice Supports spending native token with rolling limits.
/// @notice Only allow calls to a single allowed contract using IPermissionCallable.permissionedCall.
///
/// @dev Called by PermissionManager at end of its validation flow.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)

contract NativeTokenRollingSpendLimitPermission is IPermissionContract {
    /// @notice Spend of native token at a timestamp
    ///
    /// @dev Only supports individual spend value <= 1e65 to support packing and realistic cases
    struct Spend {
        uint48 timestamp;
        uint208 value;
    }

    /// @notice Spend value exceeds max size of uint208
    error SpendValueOverflow();

    /// @notice Spend value exceeds permission's spending limit
    error ExceededSpendingLimit();

    /// @notice Spend in user operation not registered at end of execution.
    error MissingAssertSpend();

    /// @notice MagicSpend withdraw asset is not native token.
    error InvalidWithdrawAsset();

    /// @notice Register native token spend for a permission
    event SpendRegistered(address indexed account, bytes32 indexed permissionHash, uint256 value);

    PermissionManager public immutable permissionManager;

    /// @notice Count of native token spends per permission per account.
    ///
    /// @dev last mapping key must be account address for 4337 slot access.
    mapping(bytes32 permissionHash => mapping(address account => uint256 count)) private _permissionSpendCount;

    /// @notice All native token spends per permission per account.
    ///
    /// @dev last mapping key must be account address for 4337 slot access.
    mapping(bytes32 permissionHash => mapping(uint256 spendIndex => mapping(address account => Spend spend))) private
        _permissionSpend;

    constructor(address manager) {
        permissionManager = PermissionManager(manager);
    }

    /// @notice Only allow permissioned calls that do not exceed approved native token spend.
    ///
    /// @dev Offchain userOp construction should append assertSpend call to calls array if spending value.
    /// @dev Rolling native token spend accounting does not protect against re-entrancy where an external call could
    ///      trigger an authorized call back to the account to spend more ETH.
    /// @dev Rolling native token spend accounting overestimates spend via gas when a paymaster is not used.
    function validatePermission(bytes32 permissionHash, bytes calldata permissionData, UserOperation calldata userOp)
        external
        view
    {
        /// @dev TODO: pack spendLimit and spendPeriod
        (uint256 spendLimit, uint256 spendPeriod, address allowedContract) =
            abi.decode(permissionData, (uint256, uint256, address));

        // for each call, accumulate attempted spend and check if call allowed
        // assumes PermissionManager already enforces use of `executeBatch` selector
        ICoinbaseSmartWallet.Call[] memory calls = abi.decode(userOp.callData[4:], (ICoinbaseSmartWallet.Call[]));
        uint256 callsLen = calls.length;
        uint256 spendValue = 0;

        // increment spendValue if gas cost beared by the user
        if (
            userOp.paymasterAndData.length == 0
                || permissionManager.addPaymasterGasSpend(address(bytes20(userOp.paymasterAndData[:20])))
        ) {
            // over-debits by ~3x actual gas used
            spendValue += UserOperationUtils.getRequiredPrefund(userOp);
            // recall MagicSpend enforces withdraw to be native token when used as a paymaster
        }

        // loop over calls to validate native token spend and allowed contracts
        // start index at 1 to ignore first call, enforced by PermissionManager as validation call on itself
        for (uint256 i = 1; i < callsLen; i++) {
            ICoinbaseSmartWallet.Call memory call = calls[i];
            bytes4 selector = bytes4(call.data);
            // accumulate spend value
            spendValue += call.value;
            // check if last call and nonzero spend value, then this must be assertSpend call
            if (i == callsLen - 1 && spendValue > 0) {
                // check call is this contract and call data matches prepared assertSpend args
                bytes memory assertSpendData = abi.encodeWithSelector(
                    NativeTokenRollingSpendLimitPermission.assertSpend.selector,
                    spendValue,
                    permissionHash,
                    spendLimit,
                    spendPeriod
                );
                if (call.target != address(this) || keccak256(call.data) != keccak256(assertSpendData)) {
                    revert MissingAssertSpend();
                }
            } else if (selector == IPermissionCallable.permissionedCall.selector) {
                // check call target is the allowed contract
                // assume PermissionManager already prevents account as target
                if (call.target != allowedContract) revert UserOperationUtils.TargetNotAllowed();
            } else if (selector == MagicSpend.withdraw.selector) {
                // parse MagicSpend withdraw request
                MagicSpend.WithdrawRequest memory withdraw =
                    abi.decode(UserOperationUtils.sliceCallArgs(calls[i].data), (MagicSpend.WithdrawRequest));
                // check withdraw is native token
                if (withdraw.asset != address(0)) revert InvalidWithdrawAsset();
                // do not need to accrue spendValue because withdrawn value will be spent in other calls
            } else if (selector != MagicSpend.withdrawGasExcess.selector) {
                revert UserOperationUtils.SelectorNotAllowed();
            }
        }
    }

    /// @notice Register a spend of native token for a given permission.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS vector.
    function assertSpend(bytes32 permissionHash, uint256 spendValue, uint256 spendLimit, uint256 spendPeriod)
        external
    {
        // early return if no value spent
        if (spendValue == 0) return;
        // check spend value within 208 bits
        if (spendValue > type(uint208).max) revert SpendValueOverflow();
        // check spend value does not exceed limit for period
        uint256 rollingSpend = _calculateRollingSpend(msg.sender, permissionHash, spendPeriod);
        if (spendValue + rollingSpend > spendLimit) {
            revert ExceededSpendingLimit();
        }
        // add spend to state
        uint256 index = ++_permissionSpendCount[permissionHash][msg.sender];
        _permissionSpend[permissionHash][index][msg.sender] = Spend(uint48(block.timestamp), uint208(spendValue));

        emit SpendRegistered(msg.sender, permissionHash, spendValue);
    }

    /// @notice Calculate rolling spend for the period
    ///
    /// @param account The account to localize to
    /// @param permissionHash The unique permission to localize to
    /// @param spendPeriod Time in seconds to look back from now for current spend period
    ///
    /// @return rollingSpend Value of spend done by this permission in the past period
    function _calculateRollingSpend(address account, bytes32 permissionHash, uint256 spendPeriod)
        internal
        view
        returns (uint256 rollingSpend)
    {
        uint256 index = _permissionSpendCount[permissionHash][account];
        // end loop when index reaches 0 (spends indexed starting at 1)
        while (index > 0) {
            Spend memory spend = _permissionSpend[permissionHash][index][account];
            // break loop if spend is before our spend period lower bound
            if (spend.timestamp < block.timestamp - spendPeriod) {
                break;
            }
            rollingSpend += spend.value;
            index -= 1;
        }
    }
}
