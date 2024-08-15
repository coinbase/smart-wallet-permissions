// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {PermissionManager} from "../../PermissionManager.sol";
import {ICoinbaseSmartWallet} from "../../utils/ICoinbaseSmartWallet.sol";
import {Bytes} from "../../utils/Bytes.sol";
import {IMagicSpend} from "../../utils/IMagicSpend.sol";
import {UserOperation, UserOperationUtils} from "../../utils/UserOperationUtils.sol";
import {IPermissionContract} from "../IPermissionContract.sol";
import {IPermissionCallable} from "../PermissionCallable/IPermissionCallable.sol";

/// @title RollingAllowancePermission
///
/// @notice Supports spending native token and ERC20s with rolling limits.
/// @notice Only allow calls to a single allowed contract using IPermissionCallable.permissionedCall selector.
///
/// @dev Called by PermissionManager at end of its validation flow.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract RollingAllowancePermission is IPermissionContract {
    /// @notice Spend of native token at a specific time.
    struct Spend {
        /// @dev Unix timestamp of the spend.
        uint48 timestamp;
        /// @dev Amount of native token spent, max value <= 1e65.
        uint208 value;
    }

    /// @notice Allowance for Native or ERC20 token over a rolling period.
    struct RollingAllowance {
        /// @dev ERC20 contract address or address(0) for native token.
        address token;
        /// @dev Allowance value that can be spent over a rolling period.
        uint256 value;
    }

    /// @notice Approval call made on a token for an allowed contract to spend value.
    struct ERC20Approval {
        /// @dev ERC20 contract address approval is granted on.
        address erc20;
        /// @dev Spend value for the approval.
        uint256 value;
    }

    /// @notice MagicSpend withdraw asset is not native token.
    error InvalidWithdrawAsset();

    /// @notice ERC20 approval spender is not the allowed contract for the permission.
    error InvalidApprovalSpender();

    /// @notice ERC20 approval value is zero.
    error ZeroApprovalValue();

    /// @notice Call to approveRollingAllowances not made on self or with invalid data.
    error InvalidApproveAllowancesCall();

    /// @notice Call to assertSpend not made on self or with invalid data.
    error InvalidAssertSpendCall();

    /// @notice Spend value exceeds max size of uint208
    error SpendValueOverflow();

    /// @notice Spend value exceeds permission's spending limit
    error ExceededSpendingLimit();

    /// @notice Register native token spend for a permission
    event SpendRegistered(address indexed account, bytes32 indexed permissionHash, address indexed token, uint256 value);

    /// @notice Approve a rolling allowance on native token or ERC20.
    event RollingAllowanceApproved(address indexed account, bytes32 indexed permissionHash, address indexed token, uint256 rollingAllowance, uint256 rollingPeriod);

    /// @notice All native token spends per account per permission.
    mapping(address account => mapping(bytes32 permissionHash => mapping(address token => Spend[] spends))) internal _spends;

    /// @notice Rolling period for a permission.
    mapping(address account => mapping(bytes32 permissionHash => uint256 rollingPeriod)) internal _rollingPeriods;

    /// @notice Rolling token allowances for a permission.
    mapping(address account => mapping(bytes32 permissionHash => mapping(address token => uint256 allowance))) internal _rollingAllowances;

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
        (RollingAllowance[] memory rollingAllowances, uint256 rollingPeriod, address allowedContract) =
            abi.decode(permissionFields, (RollingAllowance[], uint256, address));

        // parse user operation call data as `executeBatch` arguments (call array)
        ICoinbaseSmartWallet.Call[] memory calls = abi.decode(userOp.callData[4:], (ICoinbaseSmartWallet.Call[]));

        // initialize loop accumulators
        uint256 callsNativeSpend = 0;
        ERC20Approval[] memory approvals = new ERC20Approval[](rollingAllowances.length);
        uint256 approvalCount = 0;

        // loop over calls to validate native token spend and allowed contracts
        // start index at 1 to ignore first call, enforced by PermissionManager as validation call on itself
        // end index at calls.length - 2 to ignore assertSpends call, enforced after loop as validation call on self
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
            } else if (selector == IERC20.approve.selector) {
                (address spender, uint256 value) = abi.decode(call.data, (address, uint256));
                
                // check spender is allowed contract
                if (spender != allowedContract) revert InvalidApprovalSpender();

                // check nonzero approval
                if (value == 0) revert ZeroApprovalValue();
                
                // add approval to array
                approvals[approvalCount] = ERC20Approval(call.target, value);

                // increment approval count
                ++approvalCount;
            } else if (selector == RollingAllowancePermission.approveRollingAllowances.selector) {
                // prepare expected call data for approveRollingAllowances
                bytes memory approveRollingSpendData = abi.encodeWithSelector(
                    RollingAllowancePermission.approveRollingAllowances.selector,
                    permissionHash,
                    rollingAllowances,
                    rollingPeriod
                );

                if (!_isExpectedSelfCall(call, approveRollingSpendData)) revert InvalidApproveAllowancesCall();
            } else {
                revert UserOperationUtils.SelectorNotAllowed();
            }

            // accumulate spend value
            callsNativeSpend += call.value;
        }


        // copy approvals into shorter usedApprovals array
        ERC20Approval[] memory usedApprovals = new ERC20Approval[](approvalCount);
        for (uint256 i = 0; i < approvalCount; i++) {
            usedApprovals[i] = approvals[i];
        }

        // prepare expected call data for assertSpends
        bytes memory assertSpendsData = abi.encodeWithSelector(
            RollingAllowancePermission.assertSpends.selector,
            permissionHash,
            usedApprovals,
            callsNativeSpend,
            // gasSpend is prefund required by entrypoint (ignores refund for unused gas)
            UserOperationUtils.getRequiredPrefund(userOp),
            allowedContract,
            // paymaster data is empty or first 20 bytes are contract address
            userOp.paymasterAndData.length == 0 ? address(0) : address(bytes20(userOp.paymasterAndData[:20]))
        );

        // check that last call is assertSpends
        if (!_isExpectedSelfCall(calls[calls.length - 1], assertSpendsData)) revert InvalidAssertSpendCall();
    }

    /// @notice Approve rolling token allowances.
    ///
    /// @dev Accounts can call this even if without approving the permission. 
    /// @dev Wallet interfaces recommended to block normal transactions that call this function.
    /// @dev A rolling allowance must be approved here before it can be spent in assertSpends.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param rollingAllowances Tokens and allowances to apply on the rolling period.
    /// @param rollingPeriod Time in seconds to look back from now for current spend period.
    function approveRollingAllowances(bytes32 permissionHash, RollingAllowance[] calldata rollingAllowances, uint256 rollingPeriod) external {
        if (rollingPeriod == 0) revert(); // >0
        if (_rollingPeriods[msg.sender][permissionHash] > 0) revert(); // already set
        
        _rollingPeriods[msg.sender][permissionHash] = rollingPeriod;

        uint256 rollingAllowancesLen = rollingAllowances.length;
        for (uint256 i = 0; i < rollingAllowancesLen; i++) {
            RollingAllowance memory rollingAllowance = rollingAllowances[i];
            _rollingAllowances[msg.sender][permissionHash][rollingAllowance.token] = rollingAllowance.value;
            emit RollingAllowanceApproved(msg.sender, permissionHash, rollingAllowance.token, rollingAllowance.value, rollingPeriod);
        }
    }

    /// @notice Register a spend of native token for a given permission.
    ///
    /// @dev Accounts can call this even if they did not actually spend anything, so there is a self-DOS vector.
    /// @dev State read on Manager for adding paymaster gas to total spend must happen in execution phase.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param erc20Approvals ERC20 approvals granted and used in earlier calls.
    /// @param callsSpend Value of native token spent in calls.
    /// @param gasSpend Value of native token spent by gas.
    /// @param approvalSpender External contract called by account to spend approvals.
    /// @param paymaster Paymaster used by user operation.
    function assertSpends(
        bytes32 permissionHash,
        ERC20Approval[] calldata erc20Approvals,
        uint256 callsSpend,
        uint256 gasSpend,
        address approvalSpender,
        address paymaster
    ) external {
        uint256 rollingPeriod = _rollingPeriods[msg.sender][permissionHash];
        if (rollingPeriod == 0) revert(); // not set

        uint256 totalNativeSpend = callsSpend;
        // add gas cost to total native spend if beared by the user
        if (paymaster == address(0) || permissionManager.shouldAddPaymasterGasToTotalSpend(paymaster)) {
            totalNativeSpend += gasSpend;
            // recall MagicSpend enforces withdraw to be native token when used as a paymaster
        }

        // assert native token spend
        _assertSpend(permissionHash, address(0), totalNativeSpend, rollingPeriod);

        uint256 erc20ApprovalsLen = erc20Approvals.length;
        for (uint256 i = 0; i < erc20ApprovalsLen; i++) {
            ERC20Approval memory approval = erc20Approvals[i];

            // require current allowance is now zero to verify allowance was spent in full
            if (IERC20(approval.erc20).allowance(msg.sender, approvalSpender) > 0) revert();

            // assert erc20 spend
            _assertSpend(permissionHash, approval.erc20, approval.value, rollingPeriod);
        }
    }

    /// @notice Calculate rolling spend for the period.
    ///
    /// @param account The account to localize to.
    /// @param permissionHash The unique permission to localize to.
    /// @param rollingPeriod Time in seconds to look back from now for current spend period.
    ///
    /// @return rollingSpend Value of spend done by this permission in the past period.
    function calculateRollingSpend(address account, bytes32 permissionHash, address token, uint256 rollingPeriod)
        public
        view
        returns (uint256 rollingSpend)
    {
        uint256 spendsLen = _permissionSpends[account][permissionHash][token].length;

        // loop backwards from most recent to oldest spends
        for (uint256 i = spendsLen; i > 0; i--) {
            Spend memory spend = _permissionSpends[account][permissionHash][token][i - 1];

            // break loop if spend is before our spend period lower bound
            if (spend.timestamp < block.timestamp - rollingPeriod) break;

            // increment rolling spend
            rollingSpend += spend.value;
        }
    }

    /// @notice Assert token spend on a rolling period.
    ///
    /// @param permissionHash Hash of the permission.
    /// @param token Address of the token being spent, address(0) for native token.
    /// @param totalSpend Amount of token being spent.
    /// @param rollingPeriod Amount of time in seconds to lookback for rolling spend calculation.
    function _assertSpend(
        bytes32 permissionHash,
        address token,
        uint256 totalSpend,
        uint256 rollingPeriod
    ) internal {
        // early return if no value spent
        if (totalSpend == 0) return;

        // check spend value within max value
        if (totalSpend > type(uint208).max) revert SpendValueOverflow();

        // check spend value does not exceed limit for period
        uint256 rollingSpend = calculateRollingSpend(msg.sender, permissionHash, token, rollingPeriod);
        uint256 rollingAllowance = _rollingAllowances[msg.sender][permissionHash][token];
        if (totalSpend + rollingSpend > rollingAllowance) revert ExceededSpendingLimit();

        // add spend to state
        _permissionSpends[msg.sender][permissionHash][token].push(Spend(uint48(block.timestamp), uint208(totalSpend)));

        emit SpendRegistered(msg.sender, permissionHash, token, totalSpend);
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