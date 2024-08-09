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
/// @notice EIP-1271-compatible session key implementation that supports flexible permissions and signers.
///
/// @dev Designed specifically for Coinbase Smart Wallet (https://github.com/coinbase/smart-wallet)
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract PermissionManager is IERC1271, Ownable, Pausable {
    /// @notice A time-bound permission over an account given to an external signer.
    struct Permission {
        address account;
        uint256 chainId;
        uint40 expiry; // unix timestamp in seconds
        bytes signer; // supports Ethereum addresses (EOA, smart contract) and P256 public keys (passkey, cryptokey)
        address permissionContract;
        bytes permissionData;
        address verifyingContract; // replay protection across potential future managers
        bytes approval; // signature from an account owner proving a permission is valid
    }

    /// @notice Permission is revoked.
    error RevokedPermission();

    /// @notice PermissionApproval is invalid
    error InvalidPermissionApproval();

    /// @notice Signature from permission signer does not match hash.
    error InvalidSignature();

    /// @notice Permission contract not enabled.
    error DisabledPermissionContract();

    /// @notice Permission has expired.
    error ExpiredPermission();

    /// @notice Permission contract status not changed.
    error UnchangedPermissionContractStatus();

    /// @notice Paymaster gas spend not changed.
    error UnchangedPaymasterGasSpend();

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
    mapping(bytes32 permissionHash => mapping(address account => bool revoked)) internal _revokedPermissions;

    /// @notice Track if permission contracts are enabled.
    ///
    /// @dev Storage not keyable by account, can only be accessed in execution phase.
    mapping(address permissionContract => bool enabled) internal _enabledPermissionContracts;

    /// @notice Track if a permission contract should account for gas spent by paymaster.
    ///
    /// @dev Storage not keyable by account, can only be accessed in execution phase.
    mapping(address paymaster => bool enabled) public addPaymasterGasSpend;

    /// @notice Second-factor signer owned by Coinbase, required to have approval for each userOp.
    address public cosigner;

    /// @notice Pending cosigner for a two-step rotation to limit failed userOps during rotation.
    address public pendingCosigner;

    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

    constructor(address owner, address cosigner_) Ownable(owner) Pausable() {
        _setPendingCosigner(cosigner_);
        _rotateCosigner();
    }

    /// @notice Validates a permission via EIP-1271.
    ///
    /// @dev Assumes called by CoinbaseSmartWallet where this contract is an owner.
    ///
    /// @param userOpHash Hash of user operation signed by permission signer.
    /// @param authData Variable data for validating permissioned user operation.
    function isValidSignature(bytes32 userOpHash, bytes calldata authData) external view returns (bytes4 result) {
        // assume permission, signature, cosignature, user operation encoded together
        (Permission memory permission, bytes memory signature, bytes memory cosignature, UserOperation memory userOp) =
            abi.decode(authData, (Permission, bytes, bytes, UserOperation));
        bytes32 permissionHash = hashPermission(permission);

        // check userOperation sender matches account;
        if (userOp.sender != permission.account) revert UserOperationUtils.InvalidUserOperationSender();

        // check userOp matches userOpHash
        if (UserOperationUtils.getUserOpHash(userOp) != userOpHash) {
            revert UserOperationUtils.InvalidUserOperationHash();
        }

        // check permission not revoked
        /// @dev accessing this storage passes 4337 constraints because mapping is keyed by account address last
        if (_revokedPermissions[permissionHash][permission.account]) {
            revert RevokedPermission();
        }

        // check permission approval on account
        if (EIP1271_MAGIC_VALUE != IERC1271(permission.account).isValidSignature(permissionHash, permission.approval)) {
            revert InvalidPermissionApproval();
        }

        // check permission signer's signature on userOpHash
        if (!SignatureChecker.isValidSignatureNow(userOpHash, signature, permission.signer)) revert InvalidSignature();

        // check userOp.callData is `executeBatch`
        if (bytes4(userOp.callData) != ICoinbaseSmartWallet.executeBatch.selector) {
            revert UserOperationUtils.SelectorNotAllowed();
        }

        // check first call is PermissionManager.checkBeforeCalls with proper arguments
        ICoinbaseSmartWallet.Call[] memory calls =
            abi.decode(UserOperationUtils.sliceCallArgs(userOp.callData), (ICoinbaseSmartWallet.Call[]));
        ICoinbaseSmartWallet.Call memory validationCall = calls[0];
        if (validationCall.target != address(this)) revert UserOperationUtils.TargetNotAllowed();
        bytes memory checkBeforeCallsData = abi.encodeWithSelector(
            PermissionManager.checkBeforeCalls.selector,
            permission.expiry,
            permission.permissionContract,
            userOpHash,
            cosignature
        );
        if (keccak256(validationCall.data) != keccak256(checkBeforeCallsData)) {
            revert UserOperationUtils.InvalidUserOperationCallData();
        }

        // check batch has no self-calls
        uint256 callsLen = calls.length;
        for (uint256 i = 1; i < callsLen; i++) {
            if (calls[i].target == permission.account) revert UserOperationUtils.TargetNotAllowed();
        }

        // validate permission-specific logic
        IPermissionContract(permission.permissionContract).validatePermission(
            permissionHash, permission.permissionData, userOp
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
    function checkBeforeCalls(
        uint256 expiry,
        address permissionContract,
        bytes32 userOpHash,
        bytes calldata cosignature
    ) external view whenNotPaused {
        // check permission not expired
        if (expiry < block.timestamp) revert ExpiredPermission();
        // check permission contract enabled
        if (!_enabledPermissionContracts[permissionContract]) revert DisabledPermissionContract();
        // check cosignature from cosigner or pendingCosigner
        if (
            !SignatureChecker.isValidSignatureNow(userOpHash, cosignature, abi.encode(cosigner))
                && (
                    pendingCosigner == address(0)
                        || !SignatureChecker.isValidSignatureNow(userOpHash, cosignature, abi.encode(pendingCosigner))
                )
        ) revert InvalidSignature();
    }

    /// @notice Revoke a permission to disable its use indefinitely.
    ///
    /// @dev Depending on permission contract implementation, permissions can revoke other permissions.
    ///
    /// @param permissionHash hash of the permission to revoke
    function revokePermission(bytes32 permissionHash) external {
        if (_revokedPermissions[permissionHash][msg.sender]) {
            revert RevokedPermission();
        }
        _revokedPermissions[permissionHash][msg.sender] = true;

        emit PermissionRevoked(msg.sender, permissionHash);
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
                keccak256(permission.permissionData),
                address(this)
            )
        );
    }

    /// @notice Get permission contract enabled status.
    ///
    /// @param permissionContract The contract resposible for checking permission logic.
    ///
    /// @return enabled True if the contract is enabled.
    function isPermissionContractEnabled(address permissionContract) external view returns (bool enabled) {
        return _enabledPermissionContracts[permissionContract];
    }

    /// @notice Set permission contract enabled status.
    ///
    /// @param permissionContract The contract resposible for checking permission logic.
    /// @param enabled True if the contract is enabled.
    function setPermissionContract(address permissionContract, bool enabled) external onlyOwner {
        if (_enabledPermissionContracts[permissionContract] == enabled) {
            revert UnchangedPermissionContractStatus();
        }
        _enabledPermissionContracts[permissionContract] = enabled;
        emit PermissionContractUpdated(permissionContract, enabled);
    }

    /// @notice Set paymaster should add gas spend or not.
    ///
    /// @param paymaster The paymaster contract, potentially spending user assets.
    /// @param addGasSpend The new setting to add gas spend or not.
    function setPaymasterGasSpend(address paymaster, bool addGasSpend) external onlyOwner {
        if (addPaymasterGasSpend[paymaster] == addGasSpend) {
            revert UnchangedPaymasterGasSpend();
        }
        addPaymasterGasSpend[paymaster] = addGasSpend;
        emit PaymasterGasSpendUpdated(paymaster, addGasSpend);
    }

    /// @notice Pause the manager contract from processing any userOps.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the manager contract to enable processing userOps again.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Add pending cosigner.
    function setPendingCosigner(address newCosigner) external onlyOwner {
        _setPendingCosigner(newCosigner);
    }

    /// @notice Rotate cosigners.
    function rotateCosigner() external onlyOwner {
        _rotateCosigner();
    }

    /// @notice Add pending cosigner.
    function _setPendingCosigner(address newCosigner) internal {
        pendingCosigner = newCosigner;
        emit PendingCosignerSet(newCosigner);
    }

    /// @notice Rotate cosigners.
    function _rotateCosigner() internal {
        if (pendingCosigner == address(0)) revert MissingPendingCosigner();
        emit CosignerRotated(cosigner, pendingCosigner);
        cosigner = pendingCosigner;
        pendingCosigner = address(0);
    }
}
