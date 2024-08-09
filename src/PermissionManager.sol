// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";

import {IPermissionContract} from "./permissions/IPermissionContract.sol";
import {ICoinbaseSmartWallet} from "./utils/ICoinbaseSmartWallet.sol";
import {SignatureChecker} from "./utils/SignatureChecker.sol";
import {UserOperation, UserOperationUtils} from "./utils/UserOperationUtils.sol";

/// @title PermissionManager
///
/// @notice A dynamic permission system built into an EIP-1271 module designed for Coinbase Smart Wallet
///         (https://github.com/coinbase/smart-wallet).
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract PermissionManager is IERC1271, Ownable, Pausable {
    /// @notice A time-bound permission over an account given to an external signer.
    struct Permission {
        /// @dev Smart wallet address this permission is valid for.
        address account;
        /// @dev Chain this permision is valid for.
        uint256 chainId;
        /// @dev Unix timestamp this permission is valid until.
        uint40 expiry;
        /// @dev Non-account entity given permission to sign user operations.
        /// @dev Supports Ethereum addresses (EOA, smart contract) and P256 public keys (passkey, cryptokey).
        bytes signer;
        /// @dev External contract to verify specific permission logic.
        address permissionContract;
        /// @dev Additional arguments sent to permissionContract for validation.
        bytes permissionFields;
        /// @dev Manager contract that verifies permissions for replay protection across potential future managers.
        address verifyingContract;
        /// @dev Optional signature from account owner proving a permission is approved.
        bytes approval;
    }

    /// @notice Permission is revoked.
    error RevokedPermission();

    /// @notice Permission is approved.
    error ApprovedPermission();

    /// @notice PermissionApproval is invalid
    error InvalidPermissionApproval();

    /// @notice Signature from permission signer does not match hash.
    error InvalidSignature();

    /// @notice Permission contract not enabled.
    error DisabledPermissionContract();

    /// @notice Permission has expired.
    error ExpiredPermission();

    /// @notice Tried to rotate cosigner without a pending one set.
    error MissingPendingCosigner();

    /// @notice Permission contract setting updated.
    ///
    /// @param permissionContract The contract resposible for checking permission logic.
    /// @param enabled The new setting allowing/preventing use.
    event PermissionContractUpdated(address indexed permissionContract, bool enabled);

    /// @notice Paymaster gas spend setting updated.
    ///
    /// @param paymaster The paymaster contract, potentially spending user assets.
    /// @param addGasSpend The new setting to add gas spend or not.
    event PaymasterGasSpendUpdated(address indexed paymaster, bool addGasSpend);

    /// @notice Permission was revoked prematurely by account.
    ///
    /// @param account The smart contract account the permission controlled.
    /// @param permissionHash The unique hash representing the permission.
    event PermissionRevoked(address indexed account, bytes32 indexed permissionHash);

    /// @notice Permission was approved via transaction.
    ///
    /// @param account The smart contract account the permission controls.
    /// @param permissionHash The unique hash representing the permission.
    event PermissionApproved(address indexed account, bytes32 indexed permissionHash);

    /// @notice Pending cosigner set, initiating rotation.
    ///
    /// @param newCosigner Address of the new cosigner.
    event PendingCosignerSet(address indexed newCosigner);

    /// @notice Cosigner was updated to a new address.
    ///
    /// @dev Pending cosigner storage reset on rotation.
    ///
    /// @param oldCosigner Address of the old cosigner.
    /// @param newCosigner Address of the new cosigner.
    event CosignerRotated(address indexed oldCosigner, address indexed newCosigner);

    /// @notice Track if permissions are revoked by accounts.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 permissionHash => mapping(address account => bool revoked)) public isPermissionRevoked;

    /// @notice Track if permissions are approved by accounts via transactions.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 permissionHash => mapping(address account => bool approved)) internal _approvedPermissions;

    /// @notice Track if permission contracts are enabled.
    ///
    /// @dev Storage not keyable by account, can only be accessed in execution phase.
    mapping(address permissionContract => bool enabled) public isPermissionContractEnabled;

    /// @notice Track if a permission contract should account for gas spent by paymaster.
    ///
    /// @dev Storage not keyable by account, can only be accessed in execution phase.
    mapping(address paymaster => bool enabled) public shouldAddPaymasterGasToTotalSpend;

    /// @notice Second-factor signer owned by Coinbase, required to have approval for each userOp.
    address public cosigner;

    /// @notice Pending cosigner for a two-step rotation to limit failed userOps during rotation.
    address public pendingCosigner;

    /// @dev bytes4(keccak256("isValidSignature(bytes32,bytes)"))
    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

    constructor(address owner, address cosigner_) Ownable(owner) Pausable() {
        cosigner = cosigner_;
        emit CosignerRotated(address(0), cosigner_);
    }

    /// @notice Validates a permission via EIP-1271.
    ///
    /// @dev Assumes called by CoinbaseSmartWallet where this contract is an owner.
    /// @dev All accessed storage must be nested by account address to pass ERC-4337 constraints.
    ///
    /// @param userOpHash Hash of user operation signed by permission signer.
    /// @param authData Variable data for validating permissioned user operation.
    function isValidSignature(bytes32 userOpHash, bytes calldata authData) external view returns (bytes4 result) {
        // assume specific encoding of authData
        (
            UserOperation memory userOp,
            bytes memory userOpSignature, // signed by permission signer
            bytes memory userOpCosignature, // signed by cosigner
            Permission memory permission // approved by user
        ) = abi.decode(authData, (UserOperation, bytes, bytes, Permission));
        bytes32 permissionHash = hashPermission(permission);

        // check userOperation sender matches account;
        if (userOp.sender != permission.account) revert UserOperationUtils.InvalidUserOperationSender();

        // check userOp matches userOpHash
        if (UserOperationUtils.getUserOpHash(userOp) != userOpHash) {
            revert UserOperationUtils.InvalidUserOperationHash();
        }

        // check permission not revoked
        if (isPermissionRevoked[permissionHash][permission.account]) {
            revert RevokedPermission();
        }

        // check permission is approved via storage or signature
        if (
            !_approvedPermissions[permissionHash][permission.account]
                && EIP1271_MAGIC_VALUE != IERC1271(permission.account).isValidSignature(permissionHash, permission.approval)
        ) {
            revert InvalidPermissionApproval();
        }

        // check permission signer signed userOpHash
        if (!SignatureChecker.isValidSignatureNow(userOpHash, userOpSignature, permission.signer)) {
            revert InvalidSignature();
        }

        // check userOp.callData is `executeBatch`
        if (bytes4(userOp.callData) != ICoinbaseSmartWallet.executeBatch.selector) {
            revert UserOperationUtils.SelectorNotAllowed();
        }

        // decode userOp calldata as `executeBatch` args (call array)
        ICoinbaseSmartWallet.Call[] memory calls =
            abi.decode(UserOperationUtils.sliceCallArgs(userOp.callData), (ICoinbaseSmartWallet.Call[]));

        // check first call target is PermissionManager
        if (calls[0].target != address(this)) revert UserOperationUtils.TargetNotAllowed();

        // check first call data is `checkBeforeCalls` with proper arguments
        bytes memory checkBeforeCallsData = abi.encodeWithSelector(
            PermissionManager.checkBeforeCalls.selector,
            permission.expiry,
            permission.permissionContract,
            userOpHash,
            userOpCosignature
        );
        if (keccak256(calls[0].data) != keccak256(checkBeforeCallsData)) {
            revert UserOperationUtils.InvalidUserOperationCallData();
        }

        // check calls batch has no self-calls
        uint256 callsLen = calls.length;
        for (uint256 i = 1; i < callsLen; i++) {
            if (calls[i].target == permission.account) revert UserOperationUtils.TargetNotAllowed();
        }

        // validate permission-specific logic
        IPermissionContract(permission.permissionContract).validatePermission(
            permissionHash, permission.permissionFields, userOp
        );

        // return back to account to complete owner signature verification of userOpHash
        return EIP1271_MAGIC_VALUE;
    }

    /// @notice Check permission constraints not allowed during userOp validation phase as first call in batch.
    ///
    /// @dev Accessing data only available in execution-phase:
    ///      * Manager paused state
    ///      * Expiry TIMESTAMP opcode
    ///      * Enabled permission contract state
    ///      * Cosigner and pendingCosigner state
    ///
    /// @param expiry Unix timestamp this permission is valid until.
    /// @param permissionContract External contract to verify specific permission logic.
    /// @param userOpHash Hash of the user operation currently executing.
    /// @param userOpCosignature Signature of userOpHash from a cosigner or pending cosigner.
    function checkBeforeCalls(
        uint256 expiry,
        address permissionContract,
        bytes32 userOpHash,
        bytes calldata userOpCosignature
    ) external view whenNotPaused {
        // check permission not expired
        if (expiry < block.timestamp) revert ExpiredPermission();

        // check permission contract enabled
        if (!isPermissionContractEnabled[permissionContract]) revert DisabledPermissionContract();

        // check userOpCosignature from cosigner or pendingCosigner
        if (
            !(
                SignatureChecker.isValidSignatureNow(userOpHash, userOpCosignature, abi.encode(cosigner))
                    || (SignatureChecker.isValidSignatureNow(userOpHash, userOpCosignature, abi.encode(pendingCosigner)))
            )
        ) revert InvalidSignature();
    }

    /// @notice Revoke a permission to disable its use indefinitely.
    ///
    /// @dev Depending on permission contract implementation, permissions can revoke other permissions.
    ///
    /// @param permissionHash hash of the permission to revoke
    function revokePermission(bytes32 permissionHash) external {
        if (isPermissionRevoked[permissionHash][msg.sender]) {
            revert RevokedPermission();
        }
        isPermissionRevoked[permissionHash][msg.sender] = true;

        emit PermissionRevoked(msg.sender, permissionHash);
    }

    /// @notice Approve a permission to enable its use in user operations.
    ///
    /// @dev Entire Permission struct taken as argument for indexers to cache relevant data.
    /// @dev Permissions can also be validated just-in-time via approval signatures instead of approval storage.
    /// @dev This can be called by anyone after an approval signature has been used for gas optimization.
    ///
    /// @param permission Details of the permission.
    function approvePermission(Permission calldata permission) external {
        bytes32 permissionHash = hashPermission(permission);

        // check sender is permission account or approval signature is valid for permission account
        if (
            msg.sender != permission.account
                && EIP1271_MAGIC_VALUE != IERC1271(permission.account).isValidSignature(permissionHash, permission.approval)
        ) {
            revert InvalidPermissionApproval();
        }

        // check permission contract enabled
        if (!_enabledPermissionContracts[permission.permissionContract]) revert DisabledPermissionContract();

        // check permission not revoked
        if (_revokedPermissions[permissionHash][permission.account]) {
            revert RevokedPermission();
        }

        // check permission not approved
        if (_approvedPermissions[permissionHash][permission.account]) {
            revert ApprovedPermission();
        }

        _approvedPermissions[permissionHash][permission.account] = true;

        emit PermissionApproved(permission.account, permissionHash);
    }

    /// @notice Hash a Permission struct for signing.
    ///
    /// @dev Important that this hash cannot be phished via EIP-191/712 or other method.
    ///
    /// @param permission Struct to hash.
    function hashPermission(Permission memory permission) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                permission.account,
                block.chainid,
                permission.expiry,
                keccak256(permission.signer),
                permission.permissionContract,
                keccak256(permission.permissionFields),
                address(this) // verifyingContract
            )
        );
    }

    /// @notice Set permission contract enabled status.
    ///
    /// @param permissionContract The contract resposible for checking permission logic.
    /// @param enabled True if the contract is enabled.
    function setPermissionContractEnabled(address permissionContract, bool enabled) external onlyOwner {
        isPermissionContractEnabled[permissionContract] = enabled;
        emit PermissionContractUpdated(permissionContract, enabled);
    }

    /// @notice Set paymaster should add gas spend or not.
    ///
    /// @param paymaster The paymaster contract, potentially spending user assets.
    /// @param addGasSpend The new setting to add gas spend or not.
    function setShouldAddPaymasterGasToTotalSpend(address paymaster, bool addGasSpend) external onlyOwner {
        shouldAddPaymasterGasToTotalSpend[paymaster] = addGasSpend;
        emit PaymasterGasSpendUpdated(paymaster, addGasSpend);
    }

    /// @notice Add pending cosigner.
    ///
    /// @param newCosigner Address of new cosigner to rotate to.
    function setPendingCosigner(address newCosigner) external onlyOwner {
        pendingCosigner = newCosigner;
        emit PendingCosignerSet(newCosigner);
    }

    /// @notice Rotate cosigners.
    function rotateCosigner() external onlyOwner {
        if (pendingCosigner == address(0)) revert MissingPendingCosigner();
        emit CosignerRotated(cosigner, pendingCosigner);
        cosigner = pendingCosigner;
        pendingCosigner = address(0);
    }

    /// @notice Pause the manager contract from processing any userOps.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the manager contract to enable processing userOps again.
    function unpause() external onlyOwner {
        _unpause();
    }
}
