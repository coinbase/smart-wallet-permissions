// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable, Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

import {IPermissionContract} from "./interfaces/IPermissionContract.sol";
import {BytesLib} from "./utils/BytesLib.sol";
import {P256SignatureCheckerLib} from "./utils/P256SignatureCheckerLib.sol";
import {UserOperation, UserOperationLib} from "./utils/UserOperationLib.sol";

/// @title PermissionManager
///
/// @notice A dynamic permission system built into an EIP-1271 module designed for Coinbase Smart Wallet
///         (https://github.com/coinbase/smart-wallet).
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
contract PermissionManager is IERC1271, Ownable2Step, Pausable {
    /// @notice Authentication data for signature validation over user operation hashes.
    /// NOTE: I find AuthData kinda a confusing name. Should it be like CallSpecification or something? 
    /// wasn't immediately obvious to me we needed this per call. 
    struct AuthData {
        /// @dev User operation (v0.6) to validate for.
        UserOperation userOp;
        /// @dev `Permission.signer` signature of user operation hash.
        bytes userOpSignature;
        /// @dev `this.cosigner` signature of user operation hash.
        bytes userOpCosignature;
        /// @dev Permission details
        Permission permission;
    }

    /// @notice A limited permission for an external signer to use an account.
    struct Permission {
        /// @dev smart account address this permission is valid for.
        address account;
        /// @dev Chain this permision is valid for.
        uint256 chainId;
        /// @dev Unix timestamp in seconds this permission is valid until.
        uint48 expiry;
        /// @dev The entity that has limited control of `account` in this Permission. 
        /// @dev Supports abi-encoded Ethereum addresses (EOA, smart contract) and P256 public keys (passkey, cryptokey).
        bytes signer;
        /// @dev External contract to verify specific permission logic.
        /// NOTE: Maybe permissionValidator or something? 
        address permissionContract;
        /// @dev Permission-specific values sent to permissionContract for validation.
        /// NOTE: Should this be permissionData ? 
        bytes permissionValues;
        /// @dev Manager contract that verifies permissions for replay protection across potential future managers.
        /// NOTE: hmmm not sure i understand this. 
        address verifyingContract;
        /// @dev Optional signature from account owner proving a permission is approved.
        bytes approval;
    }

    /// @dev bytes4(keccak256("isValidSignature(bytes32,bytes)"))
    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

    /// @notice Second-factor signer owned by Coinbase, required to have approval for each userOp.
    /// >  signer owned by Coinbase --- should we specify this more generically? A co-signer which must 
    /// sign all permission calls for them to be considered valid 
    address public cosigner;

    /// @notice Pending cosigner for a two-step rotation to limit failed userOps during rotation.
    address public pendingCosigner;

    /// @notice Track if permission contracts are enabled.
    ///
    /// @dev Storage not keyable by account, can only be accessed in execution phase.
    mapping(address permissionContract => bool enabled) public isPermissionContractEnabled;

    /// @notice Track if paymasters are enabled.
    ///
    /// @dev Storage not keyable by account, can only be accessed in execution phase.
    mapping(address paymaster => bool enabled) public isPaymasterEnabled;

    /// @notice Track if permissions are revoked by accounts.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 permissionHash => mapping(address account => bool revoked)) public isPermissionRevoked;

    /// @notice Track if permissions are approved by accounts via transactions.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 permissionHash => mapping(address account => bool approved)) internal _isPermissionApproved;

    /// @notice Permission is revoked.
    ///
    /// @param permissionHash Hash of the permission.
    error RevokedPermission(bytes32 permissionHash);

    /// @notice PermissionApproval is invalid
    error InvalidPermissionApproval();

    /// @notice Invalid signature.
    error InvalidSignature();

    /// @notice Invalid beforeCalls call.
    error InvalidBeforeCallsCall();

    /// @notice Permission has expired.
    ///
    /// @param expiry Timestamp for when the permission expired (unix seconds).
    error ExpiredPermission(uint48 expiry);

    /// @notice Permission contract not enabled.
    ///
    /// @param permissionContract The contract resposible for checking permission logic.
    error DisabledPermissionContract(address permissionContract);

    /// @notice Paymaster contract not enabled.
    ///
    /// @param paymaster ERC-4337 paymaster contract.
    error DisabledPaymaster(address paymaster);

    /// @notice Invalid cosigner.
    ///
    /// @param cosigner Address of the cosigner.
    error InvalidCosigner(address cosigner);

    /// @notice Tried to rotate cosigner to zero address.
    error PendingCosignerIsZeroAddress();

    /// @notice Renouncing ownership attempted but not allowed.
    error CannotRenounceOwnership();

    /// @notice Permission contract setting updated.
    ///
    /// @param permissionContract The contract resposible for checking permission logic.
    /// @param enabled The new setting allowing/preventing use.
    event PermissionContractUpdated(address indexed permissionContract, bool enabled);

    /// @notice Paymaster setting updated.
    ///
    /// @param paymaster ERC-4337 paymaster contract.
    /// @param enabled The new setting allowing/preventing use.
    event PaymasterUpdated(address indexed paymaster, bool enabled);

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

    /// @notice Constructor.
    ///
    /// @param initialOwner Owner responsible for managing security controls.
    /// @param initialCosigner EOA responsible for cosigning user operations for abuse mitigation.
    constructor(address initialOwner, address initialCosigner) Ownable(initialOwner) Pausable() {
        // check cosigner non-zero
        if (initialCosigner == address(0)) revert PendingCosignerIsZeroAddress();
        cosigner = initialCosigner;
        // NOTE: Is there an internal method that emits this same event which we could call? If not, should we factor out? 
        emit CosignerRotated(address(0), initialCosigner);
    }

    /// @notice Validates a permission via EIP-1271.
    ///
    /// @dev Assumes called by CoinbaseSmartWallet where this contract is an owner.
    /// NOTE which parts assumes CoinbaseSmartWallet ? 
    /// @dev All accessed storage must be nested by account address to pass ERC-4337 constraints.
    ///
    /// @param userOpHash Hash of user operation signed by permission signer.
    /// @param authData Variable data for validating permissioned user operation.
    function isValidSignature(bytes32 userOpHash, bytes calldata authData) external view returns (bytes4 result) {
        (AuthData memory data) = abi.decode(authData, (AuthData));
        bytes32 permissionHash = hashPermission(data.permission);

        // check userOperation sender matches account;
        if (data.userOp.sender != data.permission.account) {
            revert UserOperationLib.InvalidUserOperationSender(data.userOp.sender);
        }

        // check userOp matches userOpHash
        if (UserOperationLib.getUserOpHash(data.userOp) != userOpHash) {
            revert UserOperationLib.InvalidUserOperationHash(UserOperationLib.getUserOpHash(data.userOp));
        }

        // check permission not revoked
        /// NOTE: Should revoke check go in isPermissionApproved?
        if (isPermissionRevoked[permissionHash][data.permission.account]) revert RevokedPermission(permissionHash);

        // check permission approved
        if (!isPermissionApproved(data.permission)) revert InvalidPermissionApproval();

        // check permission signer signed userOpHash
        /// NOTE: I don't think P256SignatureCheckerLib is accurate given it also supports secp256k1 signatures, and 1271 generally? 
        if (!P256SignatureCheckerLib.isValidSignatureNow(userOpHash, data.userOpSignature, data.permission.signer)) {
            revert InvalidSignature();
        }

        // check paymaster is being used, i.e. non-zero
        address paymaster = UserOperationLib.getPaymaster(data.userOp.paymasterAndData);
        if (paymaster == address(0)) revert DisabledPaymaster(address(0));

        // parse cosigner from cosignature
        // NOTE: should this be specified or should we assume it must be the cosigner that we have stored?
        address userOpCosigner = ECDSA.recover(userOpHash, data.userOpCosignature);

        // check userOp.callData is `executeBatch`
        if (bytes4(data.userOp.callData) != CoinbaseSmartWallet.executeBatch.selector) {
            revert UserOperationLib.SelectorNotAllowed(bytes4(data.userOp.callData));
        }

        CoinbaseSmartWallet.Call[] memory calls =
            abi.decode(BytesLib.trimSelector(data.userOp.callData), (CoinbaseSmartWallet.Call[]));

        // prepare beforeCalls data
        bytes memory beforeCallsData =
            abi.encodeWithSelector(PermissionManager.beforeCalls.selector, data.permission, paymaster, userOpCosigner);

        // check first call is valid self.beforeCalls
        if (calls[0].target != address(this) || !BytesLib.eq(calls[0].data, beforeCallsData)) {
            revert InvalidBeforeCallsCall();
        }

        // check calls batch has no self-calls
        uint256 callsLen = calls.length;
        for (uint256 i = 1; i < callsLen; i++) {
            // prevent account and PermissionManager direct re-entrancy
            // NOTE what would be the consequence of this? :thinking
            if (calls[i].target == data.permission.account || calls[i].target == address(this)) {
                revert UserOperationLib.TargetNotAllowed(calls[i].target);
            }
        }

        // validate permission-specific logic
        IPermissionContract(data.permission.permissionContract).validatePermission(
            permissionHash, data.permission.permissionValues, data.userOp
        );

        // return back to account to complete owner signature verification of userOpHash
        return EIP1271_MAGIC_VALUE;
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
                keccak256(permission.permissionValues),
                address(this) // verifyingContract
            )
        );
    }

    /// @notice Verify if permission is approved via storage or approval signature.
    ///
    /// @param permission Fields of the permission (struct).
    ///
    /// @return approved True if permission is approved.
    function isPermissionApproved(Permission memory permission) public view returns (bool) {
        /// NOTE: this should return false if revoked?
        bytes32 permissionHash = hashPermission(permission);

        // check if approval storage has been set, i.e. permission has been used
        if (_isPermissionApproved[permissionHash][permission.account]) {
            return true;
        }

        // fallback check permission approved via signature
        return IERC1271(permission.account).isValidSignature(permissionHash, permission.approval) == EIP1271_MAGIC_VALUE;
    }

    /// @notice Check permission constraints not allowed during userOp validation phase as first call in batch.
    ///
    /// @dev Accessing data only available in execution-phase:
    ///      * Manager paused state
    ///      * Expiry TIMESTAMP opcode
    ///      * Enabled permission contract state
    ///      * Enabled paymaster state
    ///      * Cosigner and pendingCosigner state
    ///
    /// @param permission Details of the permission.
    /// @param paymaster Paymaster contract address.
    /// @param userOpCosigner Address of recovered cosigner from cosignature in validation phase.
    /// NOTE: Should be above view functions 
    function beforeCalls(Permission calldata permission, address paymaster, address userOpCosigner)
        external
        whenNotPaused
    {
        // check permission not expired
        if (permission.expiry < block.timestamp) revert ExpiredPermission(permission.expiry);

        // check permission contract enabled
        if (!isPermissionContractEnabled[permission.permissionContract]) {
            revert DisabledPermissionContract(permission.permissionContract);
        }

        // check paymaster enabled
        if (!isPaymasterEnabled[paymaster]) revert DisabledPaymaster(paymaster);

        // check userOpCosigner is cosigner or pendingCosigner
        // NOTE: hmm do we really need to solve for pending cosigner :thinking. 
        // I guess we could have lots of inflight transactions that suddendly stop working. Need to think about how 
        // we would do this hand over 
        if (userOpCosigner != cosigner && userOpCosigner != pendingCosigner) revert InvalidCosigner(userOpCosigner);

        // approve permission to cache storage for cheaper execution on future use
        approvePermission(permission);
    }

    /// @notice Approve a permission to enable its use in user operations.
    ///
    /// @dev Entire Permission struct taken as argument for indexers to cache relevant data.
    /// @dev Permissions can also be validated just-in-time via approval signatures instead of approval storage.
    /// @dev This can be called by anyone after an approval signature has been used for gas optimization.
    ///
    /// @param permission Details of the permission.
    /// NOTE: should be above view functions 
    function approvePermission(Permission calldata permission) public {
        bytes32 permissionHash = hashPermission(permission);

        // early return if permission is already approved
        if (_isPermissionApproved[permissionHash][permission.account]) {
            return;
        }

        // check sender is permission account or approval signature is valid for permission account
        if (
            !(
                msg.sender == permission.account
                    || EIP1271_MAGIC_VALUE
                        == IERC1271(permission.account).isValidSignature(permissionHash, permission.approval)
            )
        ) {
            revert InvalidPermissionApproval();
        }

        _isPermissionApproved[permissionHash][permission.account] = true;
        emit PermissionApproved(permission.account, permissionHash);

        // initialize permission via external call to permission contract
        IPermissionContract(permission.permissionContract).initializePermission(
            permission.account, permissionHash, permission.permissionValues
        );
    }

    /// @notice Revoke a permission to disable its use indefinitely.
    ///
    /// @dev Depending on permission contract implementation, permissions can revoke other permissions.
    ///
    /// @param permissionHash hash of the permission to revoke
    function revokePermission(bytes32 permissionHash) external {
        // early return if permission is already revoked
        if (isPermissionRevoked[permissionHash][msg.sender]) {
            return;
        }

        isPermissionRevoked[permissionHash][msg.sender] = true;
        emit PermissionRevoked(msg.sender, permissionHash);
    }

    /// @notice Set permission contract enabled status.
    ///
    /// @param permissionContract The contract resposible for checking permission logic.
    /// @param enabled True if the contract is enabled.
    function setPermissionContractEnabled(address permissionContract, bool enabled) external onlyOwner {
        isPermissionContractEnabled[permissionContract] = enabled;
        emit PermissionContractUpdated(permissionContract, enabled);
    }

    /// @notice Set paymaster enabled status.
    ///
    /// @param paymaster ERC-4337 paymaster contract.
    /// @param enabled True if the contract is enabled.
    function setPaymasterEnabled(address paymaster, bool enabled) external onlyOwner {
        // never allow no-paymaster, reverting to keep event feed not confusing if accidental enablement made
        if (paymaster == address(0)) revert DisabledPaymaster(address(0));
        isPaymasterEnabled[paymaster] = enabled;
        emit PaymasterUpdated(paymaster, enabled);
    }

    /// @notice Add pending cosigner.
    ///
    /// @param newCosigner Address of new cosigner to rotate to.
    /// NOTE: Should we have used some off the shelf roles contract so that we didn't have to roll our own? 
    function setPendingCosigner(address newCosigner) external onlyOwner {
        if (pendingCosigner == address(0)) revert PendingCosignerIsZeroAddress();
        pendingCosigner = newCosigner;
        emit PendingCosignerSet(newCosigner);
    }

    /// @notice Reset pending cosigner to zero address.
    /// NOTE: should pending cosigner be able to call this? 
    function resetPendingCosigner() external onlyOwner {
        pendingCosigner = address(0);
        emit PendingCosignerSet(address(0));
    }

    /// @notice Rotate cosigners.
    /// NOTE: rotate is confusing, can we call this like acceptPendingCosigner 
    function rotateCosigner() external onlyOwner {
        if (pendingCosigner == address(0)) revert PendingCosignerIsZeroAddress();
        // NOTE: why event before setting state? Seems non idiomatic 
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

    /// @notice Renounce ownership of this contract.
    ///
    /// @dev Overidden to always revert to prevent accidental renouncing.
    function renounceOwnership() public view override onlyOwner {
        revert CannotRenounceOwnership();
    }
}
