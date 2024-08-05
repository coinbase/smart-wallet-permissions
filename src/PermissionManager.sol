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

    /// @notice Permission account does not match currently authentication sender.
    error InvalidPermissionAccount();

    /// @notice Permission chain is not agnositc and not this chain.
    error InvalidPermissionChain();

    /// @notice Permission verifying contract is not this PermissionManager.
    error InvalidPermissionVerifyingContract();

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

    /// @notice Tried to rotate cosigner without a pending one set.
    error MissingPendingCosigner();

    /// @notice Permission contract setting updated
    ///
    /// @param permissionContract The contract resposible for checking permission logic.
    /// @param enabled The new setting allowing/preventing use.
    event PermissionContractUpdated(address indexed permissionContract, bool enabled);

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
    /// @param hash Arbitrary data signed over, intended to only support userOpHash.
    /// @param authData Encoded group of Permission, signature from the Permission's signer for `hash`, and a
    /// UserOperation<v0.6>.
    function isValidSignature(bytes32 hash, bytes calldata authData) external view returns (bytes4 result) {
        // assume permission, signature, cosignature, user operation encoded together
        (Permission memory permission, bytes memory signature, bytes memory cosignature, UserOperation memory userOp) =
            abi.decode(authData, (Permission, bytes, bytes, UserOperation));
        bytes32 permissionHash = hashPermission(permission);

        // check userOperation sender matches account;
        if (userOp.sender != permission.account) revert UserOperationUtils.InvalidUserOperationSender();

        // check userOperation matches hash
        bytes32 userOpHash = UserOperationUtils.getUserOpHash(userOp);
        if (userOpHash != hash) revert UserOperationUtils.InvalidUserOperationHash();

        // check chainId is this chain
        if (permission.chainId != block.chainid) {
            revert InvalidPermissionChain();
        }

        // check verifyingContract is PermissionManager
        if (permission.verifyingContract != address(this)) {
            revert InvalidPermissionVerifyingContract();
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

        // check permission signer's signature on hash
        if (!SignatureChecker.isValidSignatureNow(hash, signature, permission.signer)) revert InvalidSignature();

        // check userOp.callData is `executeBatch`
        bytes4 selector = bytes4(userOp.callData);
        if (selector != ICoinbaseSmartWallet.executeBatch.selector) revert UserOperationUtils.SelectorNotAllowed();

        // check first call is PermissionManager.validatePermissionExecution with proper args
        /// @dev rely on validation call to check for paused Manager, enabled permission contract, and permission expiry
        ICoinbaseSmartWallet.Call[] memory calls =
            abi.decode(UserOperationUtils.sliceCallArgs(userOp.callData), (ICoinbaseSmartWallet.Call[]));
        ICoinbaseSmartWallet.Call memory validationCall = calls[0];
        if (validationCall.target != address(this)) revert UserOperationUtils.TargetNotAllowed();
        bytes memory validatePermissionExecutionData = abi.encodeWithSelector(
            PermissionManager.validatePermissionExecution.selector,
            hash,
            cosignature,
            permission.permissionContract,
            permission.expiry
        );
        if (keccak256(validationCall.data) != keccak256(validatePermissionExecutionData)) {
            revert UserOperationUtils.InvalidUserOperationCallData();
        }

        // check no self-calls
        uint256 callsLen = calls.length;
        for (uint256 i = 1; i < callsLen; i++) {
            if (calls[i].target == permission.account) revert UserOperationUtils.TargetNotAllowed();
            /// @dev TODO could also extend coverage to not allow targets that are owners of the account?
        }

        // validate permission-specific logic
        IPermissionContract(permission.permissionContract).validatePermission(
            permissionHash, permission.permissionData, userOp
        );

        return EIP1271_MAGIC_VALUE;
    }

    /// @notice Validate permission constraints not allowed during userOp validation phase
    ///
    /// @dev Access paused state
    /// @dev Access enabled permission contract state
    /// @dev Access cosigner and pendingCosigner state
    /// @dev Use TIMESTAMP opcode to check expiry
    function validatePermissionExecution(
        bytes32 userOpHash,
        bytes calldata cosignature,
        address permissionContract,
        uint256 expiry
    ) external view {
        // check manager not paused
        _requireNotPaused();
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
        // check permission not expired
        if (expiry < block.timestamp) revert ExpiredPermission();
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
    /// @dev important that this hash cannot be phished via EIP-191/712 or other method
    ///
    /// @param permission struct to hash
    function hashPermission(Permission memory permission) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                permission.account,
                permission.chainId,
                permission.expiry,
                keccak256(permission.signer),
                permission.permissionContract,
                keccak256(permission.permissionData),
                permission.verifyingContract
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
