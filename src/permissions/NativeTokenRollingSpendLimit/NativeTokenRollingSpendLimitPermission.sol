// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {PermissionManager} from "../../PermissionManager.sol";
import {ICoinbaseSmartWallet} from "../../utils/ICoinbaseSmartWallet.sol";
import {Bytes} from "../../utils/Bytes.sol";
import {IMagicSpend} from "../../utils/IMagicSpend.sol";
import {UserOperation, UserOperationUtils} from "../../utils/UserOperationUtils.sol";
import {IPermissionContract} from "../IPermissionContract.sol";
import {IPermissionCallable} from "../PermissionCallable/IPermissionCallable.sol";

/// @title NativeTokenRollingSpendLimitPermission
///
/// @notice Supports spending native token with rolling limits.
/// @notice Only allow calls to a single allowed contract using IPermissionCallable.permissionedCall selector.
///
/// @dev Called by PermissionManager at end of its validation flow.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract NativeTokenRollingSpendLimitPermission is IPermissionContract {
    /// @notice Spend of native token at a specific time.
    struct Spend {
        /// @dev Unix timestamp of the spend.
        uint48 timestamp;
        /// @dev Amount of native token spent, max value <= 1e65.
        uint208 value;
    }

    /// @notice MagicSpend withdraw asset is not native token.
    error InvalidWithdrawAsset();

    /// @notice Call to assertSpend not made on self or with invalid data.
    error InvalidAssertSpendCall();

    /// @notice Spend value exceeds max size of uint208
    error SpendValueOverflow();

    /// @notice Spend value exceeds permission's spending limit
    error ExceededSpendingLimit();

    /// @notice Register native token spend for a permission
    event SpendRegistered(address indexed account, bytes32 indexed permissionHash, uint256 value);

    /// @notice All native token spends per account per permission.
    mapping(address account => mapping(bytes32 permissionHash => Spend[] spends)) internal _spends;

    /// @notice PermissionManager this permission contract trusts for paymaster gas spend data.
    PermissionManager public immutable permissionManager;

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
        (uint256 spendLimit, uint256 rollingPeriod, address allowedContract) =
            abi.decode(permissionFields, (uint256, uint256, address));

        // parse user operation call data as `executeBatch` arguments (call array)
        ICoinbaseSmartWallet.Call[] memory calls = abi.decode(userOp.callData[4:], (ICoinbaseSmartWallet.Call[]));

        // initialize loop accumulators
        uint256 callsSpend = 0;

        // loop over calls to validate native token spend and allowed contracts
        // start index at 1 to ignore first call, enforced by PermissionManager as validation call on itself
        // end index at calls.length - 2 to ignore assertSpend call, enforced after loop as validation call on self
        for (uint256 i = 1; i < calls.length - 1; i++) {
            ICoinbaseSmartWallet.Call memory call = calls[i];
            bytes4 selector = bytes4(call.data);

            if (selector == IPermissionCallable.permissionedCall.selector) {
                // check call target is the allowed contract
                if (call.target != allowedContract) revert UserOperationUtils.TargetNotAllowed();
                // assume PermissionManager already prevents account as target
            } else if (selector == IMagicSpend.withdraw.selector) {
                // parse MagicSpend withdraw request
                IMagicSpend.WithdrawRequest memory withdraw =
                    abi.decode(Bytes.sliceCallArgs(calls[i].data), (IMagicSpend.WithdrawRequest));

                // check withdraw is native token
                if (withdraw.asset != address(0)) revert InvalidWithdrawAsset();
                // do not need to accrue callsSpend because withdrawn value will be spent in other calls
            } else if (selector == IMagicSpend.withdrawGasExcess.selector) {
                // ok
            } else {
                revert UserOperationUtils.SelectorNotAllowed();
            }

            // accumulate spend value
            callsSpend += call.value;
        }

        // prepare expected call data for assertSpend
        bytes memory assertSpendData = abi.encodeWithSelector(
            NativeTokenRollingSpendLimitPermission.assertSpend.selector,
            permissionHash,
            spendLimit,
            rollingPeriod,
            callsSpend,
            // gasSpend is prefund required by entrypoint (ignores refund for unused gas)
            UserOperationUtils.getRequiredPrefund(userOp),
            // paymaster data is empty or first 20 bytes are contract address
            userOp.paymasterAndData.length == 0 ? address(0) : address(bytes20(userOp.paymasterAndData[:20]))
        );

        // check that last call is assertSpend
        if (!_isExpectedSelfCall(calls[calls.length - 1], assertSpendData)) revert InvalidAssertSpendCall();
    }

    /// @notice Register a spend of native token for a given permission.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS vector.
    /// @dev State read on Manager for adding paymaster gas to total spend must happen in execution phase.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param spendLimit Value of native token that cannot be exceeded over the rolling period.
    /// @param rollingPeriod Seconds duration for the rolling period.
    /// @param callsSpend Value of native token spent in calls.
    /// @param gasSpend Value of native token spent by gas.
    /// @param paymaster Paymaster used by user operation.
    function assertSpend(
        bytes32 permissionHash,
        uint256 spendLimit,
        uint256 rollingPeriod,
        uint256 callsSpend,
        uint256 gasSpend,
        address paymaster
    ) external {
        uint256 totalSpend = callsSpend;

        // add gas cost if beared by the user
        if (paymaster == address(0) || permissionManager.shouldAddPaymasterGasToTotalSpend(paymaster)) {
            totalSpend += gasSpend;
            // recall MagicSpend enforces withdraw to be native token when used as a paymaster
        }

        // assert native token spend
        _assertSpend(permissionHash, totalSpend, spendLimit, rollingPeriod);
    }

    /// @notice Calculate rolling spend for the period.
    ///
    /// @param account The account tied to the permission.
    /// @param permissionHash Hash of the permission.
    /// @param rollingPeriod Time in seconds to look back from now for current spend period.
    ///
    /// @return rollingSpend Value of spend done by this permission in the past period.
    function calculateRollingSpend(address account, bytes32 permissionHash, uint256 rollingPeriod)
        public
        view
        returns (uint256 rollingSpend)
    {
        uint256 spendsLen = _spends[account][permissionHash].length;

        // loop backwards from most recent to oldest spends
        for (uint256 i = spendsLen; i > 0; i--) {
            Spend memory spend = _spends[account][permissionHash][i - 1];

            // break loop if spend is before our spend period lower bound
            if (spend.timestamp < block.timestamp - rollingPeriod) break;

            // increment rolling spend
            rollingSpend += spend.value;
        }
    }

    /// @notice Assert native token spend on a rolling period.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param totalSpend Amount of native token being spent.
    /// @param rollingPeriod Amount of time in seconds to lookback for rolling spend calculation.
    function _assertSpend(
        bytes32 permissionHash,
        uint256 totalSpend,
        uint256 spendLimit,
        uint256 rollingPeriod
    ) internal {
        // early return if no value spent
        if (totalSpend == 0) return;

        // check spend value within max value
        if (totalSpend > type(uint208).max) revert SpendValueOverflow();

        // check spend value does not exceed limit for period
        uint256 rollingSpend = calculateRollingSpend(msg.sender, permissionHash, rollingPeriod);
        if (totalSpend + rollingSpend > spendLimit) revert ExceededSpendingLimit();

        // add spend to state
        _spends[msg.sender][permissionHash].push(Spend(uint48(block.timestamp), uint208(totalSpend)));

        emit SpendRegistered(msg.sender, permissionHash, totalSpend);
    }

    /// @notice Check if a call is made on this contract with expected data.
    ///
    /// @param call Struct defining the call parameters (target, value, data).
    /// @param expectedData Encoded call data with specific selector and arguments on this contract.
    ///
    /// @return valid True if the call target and expected data match the call.
    function _isExpectedSelfCall(ICoinbaseSmartWallet.Call memory call, bytes memory expectedData) internal view returns (bool) {
        return (call.target == address(this) && keccak256(call.data) == keccak256(expectedData));
    }
}