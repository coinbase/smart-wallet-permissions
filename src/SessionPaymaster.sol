// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {_packValidationData} from "account-abstraction/core/Helpers.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {Ownable, Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/// @title SessionPaymaster
///
/// @notice ERC-4337 Paymaster designed to secure Session Keys users from unaccounted gas spend on their accounts.
///
/// @dev Designed as the only supported paymaster for SessionManager.
/// @dev Supports permissionless deposits and signer configuration for offchain paymaster services.
/// @dev Supports paymaster refunds from accounts within execution phase.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract SessionPaymaster is IPaymaster, Ownable2Step {
    /// @notice Data for paymaster validation.
    struct PaymasterData {
        /// @dev Entity sponsoring user operations.
        address sponsor;
        /// @dev Offchain UUID for convenient indexing and accounting.
        uint128 uuid;
        /// @dev Expiry for the sponsorship signature.
        uint48 validUntil;
        /// @dev Earliest time the sponsorship signature is valid.
        uint48 validAfter;
    }

    /// @notice Context passed from validation to postOp.
    struct PostOpContext {
        /// @dev Entity sponsoring user operations.
        address sponsor;
        /// @dev Offchain UUID for convenient indexing and accounting.
        uint128 uuid;
        /// @dev Hash of the user operation.
        bytes32 userOpHash;
        /// @dev Maximum gas cost for the user operation.
        uint256 maxGasCost;
        /// @dev `UserOperation.maxFeePerGas`
        uint256 maxFeePerGas;
        /// @dev `UserOperation.maxPriorityFeePerGas`
        uint256 maxPriorityFeePerGas;
    }

    /// @notice ERC-4337 EntryPoint.
    IEntryPoint public constant entryPoint = IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    /// @notice Estimated gas consumed by `this.postOp`
    uint256 public constant POST_OP_GAS = 69420;

    /// @notice Bytes offset of paymaster data before signature.
    uint256 internal constant PAYMASTER_SIGNATURE_OFFSET = 52;

    /// @notice Per-sponsor native token deposits.
    mapping(address sponsor => uint256 balance) internal _sponsorDeposits;

    /// @notice Per-sponsor signer allowlist for issuing sponsorship signatures.
    mapping(address sponsor => mapping(address signer => bool allowed)) public isAllowedSigner;

    /// @notice Sender not EntryPoint.
    error SenderNotEntryPoint(address sender);

    /// @notice Attempted withdraw greater than deposit balance.
    error InsufficientDepositBalance(uint256 withdraw);

    /// @notice Native token deposited for sponsor.
    ///
    /// @param depositor Entity depositing native token.
    /// @param sponsor Entity sponsoring user operations.
    /// @param value Amount of native token.
    event Deposited(address indexed depositor, address indexed sponsor, uint256 value);

    /// @notice Native token withdrawn for sponsor.
    ///
    /// @param sponsor Entity sponsoring user operations.
    /// @param recipient Entity receiving withdraw.
    /// @param value Amount of native token.
    event Withdrawn(address indexed sponsor, address recipient, uint256 value);

    /// @notice Signer updated for sponsor.
    ///
    /// @param sponsor Entity sponsoring user operations.
    /// @param signer Entity signing paymaster sponsorship requests.
    /// @param allowed True if signer is allowed for sponsor.
    event SignerUpdated(address indexed sponsor, address indexed signer, bool allowed);

    /// @notice User operation sponsored.
    ///
    /// @param sponsor Entity sponsoring user operations.
    /// @param uuid Offchain UUID for convenient indexing and accounting.
    /// @param userOpHash Hash of the user operation.
    event UserOperationSponsored(address indexed sponsor, uint128 indexed uuid, bytes32 indexed userOpHash);

    /// @notice Constructor.
    ///
    /// @param initialOwner First owner of the paymaster.
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Require sender to be EntryPoint.
    modifier onlyEntryPoint() {
        if (msg.sender != address(entryPoint)) revert SenderNotEntryPoint(msg.sender);

        _;
    }

    /// @notice Add stake to the EntryPoint.
    ///
    /// @param unstakeDelay Delay after unstaking to finalize stake withdraw (seconds).
    function addStake(uint32 unstakeDelay) external payable onlyOwner {
        entryPoint.addStake{value: msg.value}(unstakeDelay);
    }

    /// @notice Unlock stake on the EntryPoint.
    ///
    /// @dev Unlocking removes the `staked` status within the EntryPoint, notifying Bundlers to not accept storage
    ///      accesses made in validation.
    function unlockStake() external onlyOwner {
        entryPoint.unlockStake();
    }

    /// @notice Withdraw stake from the EntryPoint.
    ///
    /// @dev Cannot withdraw until `unstakeDelay` has passed after unlocking stake.
    ///
    /// @param recipient Entity receiving withdraw.
    function withdrawStake(address payable recipient) external onlyOwner {
        entryPoint.withdrawStake(recipient);
    }

    /// @notice Update signer allowed status for sponsor.
    ///
    /// @param signer Entity signing paymaster sponsorship requests.
    /// @param allowed True if signer is allowed for sponsor.
    function updateSigner(address signer, bool allowed) external {
        isAllowedSigner[msg.sender][signer] = allowed;
        emit SignerUpdated(msg.sender, signer, allowed);
    }

    /// @notice Deposit native token on behalf of a sponsor.
    ///
    /// @dev Accounts call this method within execution to refund their sponsor.
    ///
    /// @param sponsor Entity sponsoring user operations.
    function deposit(address sponsor) external payable {
        // increase deposit balance
        _sponsorDeposits[sponsor] += msg.value;

        // deposit into EntryPoint
        entryPoint.depositTo{value: msg.value}(address(this));

        emit Deposited(msg.sender, sponsor, msg.value);
    }

    /// @dev protected against withdraw within execution phase because we debit usage in validation phase
    ///
    /// @param recipient Entity receiving withdraw.
    /// @param value Amount of native token.
    function withdraw(address payable recipient, uint256 value) external {
        // check value does not exceed deposit balance
        uint256 balance = _sponsorDeposits[msg.sender];
        if (value > balance) revert InsufficientDepositBalance(value);

        // reduce deposit balance
        _sponsorDeposits[msg.sender] = balance - value;

        // withdraw deposit from EntryPoint
        entryPoint.withdrawTo(recipient, value);

        emit Withdrawn(msg.sender, recipient, value);
    }

    /// @notice Validate user operation.
    ///
    /// @dev Accesses non-associated storage, requiring this paymaster to be staked.
    /// @dev Decreases sponsor deposit balance for double-spend protection.
    ///
    /// @param userOp UserOperation to validate.
    /// @param userOpHash Hash of the user operation.
    /// @param maxGasCost Maximum possible gas cost for the user operation.
    function validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxGasCost)
        external
        onlyEntryPoint
        returns (bytes memory context, uint256 validationData)
    {
        (PaymasterData memory data, bytes memory signature) = _parsePaymasterAndData(userOp.paymasterAndData);

        // early return signature failure if sponsor does not have enough deposit balance
        if (_sponsorDeposits[data.sponsor] < maxGasCost) return ("", 1);

        // decrease sponsor balance to reserve for maximum gas cost (unused gas to be re-deposited in postOp)
        _sponsorDeposits[data.sponsor] -= maxGasCost;

        // determine if signature is valid
        bytes32 hash = ECDSA.toEthSignedMessageHash(getHash(userOp));
        // TODO: override revert to be length >= 32 for EntryPoint V0.6 quirk.
        address signer = ECDSA.recover(hash, signature);
        bool allowedSigner = isAllowedSigner[data.sponsor][signer];

        // prepare context and validation data
        context = abi.encode(
            PostOpContext({
                sponsor: data.sponsor,
                uuid: data.uuid,
                userOpHash: userOpHash,
                maxGasCost: maxGasCost,
                maxFeePerGas: userOp.maxFeePerGas,
                maxPriorityFeePerGas: userOp.maxPriorityFeePerGas
            })
        );
        validationData =
            _packValidationData({sigFailed: !allowedSigner, validUntil: data.validUntil, validAfter: data.validAfter});

        return (context, validationData);
    }

    /// @notice Handle user operation post-execution.
    ///
    /// @param mode Enum for user operation status (success/fail) or failed postOp.
    /// @param context Data prepared in validation phase.
    /// @param actualGasCost Gas cost excluding gas fee for this function execution.
    function postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) external onlyEntryPoint {
        PostOpContext memory ctx = abi.decode(context, (PostOpContext));

        if (mode != PostOpMode.postOpReverted) {
            uint256 feePerGas = FixedPointMathLib.min(ctx.maxFeePerGas, ctx.maxPriorityFeePerGas + block.basefee);
            uint256 totalGasCost = actualGasCost + POST_OP_GAS * feePerGas;
            if (totalGasCost < ctx.maxGasCost) {
                _sponsorDeposits[ctx.sponsor] += (ctx.maxGasCost - totalGasCost);
            }

            emit UserOperationSponsored(ctx.sponsor, ctx.uuid, ctx.userOpHash);
        }
    }

    /// @notice Get sponsor deposit balance.
    ///
    /// @param sponsor Entity sponsoring user operations.
    ///
    /// @return sponsorDeposit Deposit balance value (wei).
    function getSponsorDeposit(address sponsor) external view returns (uint256) {
        return _sponsorDeposits[sponsor];
    }

    /// @notice Get sponsor deposit balance.
    ///
    /// @return totalDeposit Deposit balance value (wei).
    function getTotalDeposit() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /// @notice Compute hash of user operation without paymaster signature.
    ///
    /// @param userOp User operation to sponsor.
    ///
    /// @return hash Hash of the user operation.
    function getHash(UserOperation calldata userOp) public view returns (bytes32) {
        bytes32 userOpHash = keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                keccak256(userOp.paymasterAndData[:PAYMASTER_SIGNATURE_OFFSET])
            )
        );

        return keccak256(abi.encode(userOpHash, address(this), block.chainid));
    }

    /// @notice Parse raw `userOp.paymasterAndData` bytes into struct.
    ///
    /// @param paymasterAndData Bytes for paymaster address and data.
    ///
    /// @return data PaymasterData struct.
    /// @return signature Bytes to validate a sponsor signer.
    function _parsePaymasterAndData(bytes calldata paymasterAndData)
        internal
        pure
        returns (PaymasterData memory data, bytes calldata signature)
    {
        data.sponsor = address(bytes20(paymasterAndData[20:40]));
        data.validUntil = uint48(bytes6(paymasterAndData[40:46]));
        data.validAfter = uint48(bytes6(paymasterAndData[46:52]));
        signature = paymasterAndData[PAYMASTER_SIGNATURE_OFFSET:];
    }
}
