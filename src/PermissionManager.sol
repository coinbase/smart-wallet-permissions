// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";

import {IPermissionContract} from "./permissions/IPermissionContract.sol";
import {SignatureChecker} from "./utils/SignatureChecker.sol";
import {UserOperation, UserOperationUtils} from "./utils/UserOperationUtils.sol";

/// @title PermissionManager
///
/// @notice EIP-1271-compatible session key implementation that supports flexible permissions and signers.
///
/// @dev Designed specifically for Coinbase Smart Wallet (https://github.com/coinbase/smart-wallet)
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
contract PermissionManager is IERC1271, UserOperationUtils, Ownable, Pausable {
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

    /// @notice Track if permissions are revoked by accounts.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 permissionHash => mapping(address account => bool revoked)) internal _revokedPermissions;

    /// @notice Track if permission contracts are enabled.
    ///
    /// @dev Storage not keyable by account, can only be accessed in execution phase.
    mapping(address permissionContract => bool enabled) internal _enabledPermissionContracts;

    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

    constructor(address owner) Ownable(owner) Pausable() {}

    /// @notice Validates a permission via EIP-1271.
    ///
    /// @dev Assumes called by CoinbaseSmartWallet where this contract is an owner.
    ///
    /// @param hash Arbitrary data signed over, intended to only support userOpHash.
    /// @param authData Encoded group of Permission, signature from the Permission's signer for `hash`, and a
    /// UserOperation<v0.6>.
    function isValidSignature(bytes32 hash, bytes calldata authData) external view returns (bytes4 result) {
        // assume permission, signature, user operation encoded together
        (Permission memory permission, bytes memory signature, UserOperation memory userOp) =
            abi.decode(authData, (Permission, bytes, UserOperation));
        bytes32 permissionHash = hashPermission(permission);

        // assume Manager is called by the account as part of signature validation on smart contract owner
        address account = msg.sender;

        // check userOperation sender matches account;
        _validateUserOperationSender(userOp.sender, account);

        // check userOperation matches hash
        _validateUserOperationHash(hash, userOp);

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
        if (selector != EXECUTE_BATCH_SELECTOR) revert SelectorNotAllowed();

        // check first call is PermissionManager.validatePermissionExecution with proper args
        /// @dev rely on validation call to check for paused Manager, enabled permission contract, and permission expiry
        Call[] memory calls = abi.decode(_sliceCallArgs(userOp.callData), (Call[]));
        Call memory validationCall = calls[0];
        if (validationCall.target != address(this)) revert TargetNotAllowed();
        bytes memory validatePermissionExecutionData = abi.encodeWithSelector(
            PermissionManager.validatePermissionExecution.selector, permission.permissionContract, permission.expiry
        );
        if (keccak256(validationCall.data) != keccak256(validatePermissionExecutionData)) {
            revert InvalidUserOperationCallData();
        }

        // check no self-calls
        uint256 callsLen = calls.length;
        for (uint256 i = 1; i < callsLen; i++) {
            if (calls[i].target == account) revert TargetNotAllowed();
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
    /// @dev Use TIMESTAMP opcode to check expiry
    function validatePermissionExecution(address permissionContract, uint256 expiry) external view {
        // check manager not paused
        _requireNotPaused();
        // check permission contract enabled
        if (!_enabledPermissionContracts[permissionContract]) revert DisabledPermissionContract();
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
}
