// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {IPermissionModule} from "./modules/IPermissionModule.sol";
import {SignatureChecker} from "./utils/SignatureChecker.sol";

/// @title SessionManager
///
/// @notice EIP-1271-compatible session key implementation that supports arbitrary scopes and EOA+passkey signers.
///
/// @dev Without the full UserOp and control of the execution flow, this contract only validates session validity.
///      Account implementations MUST validate scopes within their execution flow outside of validateUserOp.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
contract SessionManager is IERC1271 {
    /// @notice A time-bound provision of scoped account control to another signer.
    struct Session {
        address account;
        bytes approval;
        bytes signer;
        address permissionModule;
        bytes permissionData;
        uint40 expiresAt;
        // TODO: consider EIP-712 format instead
        uint256 chainId; // (to discuss) 0 could represent chain-agnostic i.e. this session applies on any network
        address verifyingContract; // prevent replay on other potential SessionManager implementations
    }

    /// @notice Session account does not match currently authentication sender.
    error InvalidSessionAccount();

    /// @notice Session chain is not agnositc and not this chain.
    error InvalidSessionChain();

    /// @notice Session verifying contract is not this SessionManager.
    error InvalidSessionVerifyingContract();

    /// @notice Session is revoked.
    error RevokedSession();
    
    /// @notice Session has expired.
    error ExpiredSession();
    
    /// @notice SessionApproval is invalid
    error InvalidSessionApproval();

    /// @notice Signature from session signer does not match hash.
    error InvalidSignature();

    /// @notice Session was revoked prematurely by account.
    ///
    /// @param account The smart contract account the session controlled.
    /// @param sessionId The unique hash representing the session.
    event SessionRevoked(address indexed account, bytes32 indexed sessionId);
    
    /// @dev keying storage by account enables us to pass 4337 storage access limitations
    mapping(address account => mapping(bytes32 sessionId => bool revoked)) internal _revokedSessions;

    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

    /// @notice Validates a session via EIP-1271.
    ///
    /// @dev Assumes called by CoinbaseSmartWallet where this contract is an owner.
    ///
    /// @param hash Arbitrary data to sign over.
    /// @param authData Combination of an approved Session and a signature from the session's signer for `hash`.
    function isValidSignature(bytes32 hash, bytes calldata authData) external view returns (bytes4 result) {
        // assume session, signature, attestation encoded together
        (Session memory session, bytes memory signature, bytes memory requestData) = abi.decode(authData, (Session, bytes, bytes));

        // validate core session parameters and signature
        _validateSession(session, hash, signature);
        // validate permission-specific logic
        IPermissionModule(session.permissionModule).validatePermissions(msg.sender, hash, keccak256(abi.encode(session)), session.permissionData, requestData);

        return EIP1271_MAGIC_VALUE;
    }

    function _validateSession(Session memory session, bytes32 hash, bytes memory signature) internal view {
        bytes32 sessionId = keccak256(abi.encode(session));

        // check sender is session account
        if (msg.sender != session.account) revert InvalidSessionAccount();
        // check chainId is agnostic or this chain
        if (session.chainId != 0 && session.chainId != block.chainid) revert InvalidSessionChain();
        // check verifyingContract is SessionManager
        if (session.verifyingContract != address(this)) revert InvalidSessionVerifyingContract();
        // check session not expired
        if (session.expiresAt < block.timestamp) revert ExpiredSession();
        // check session not revoked
        if (_revokedSessions[session.account][sessionId]) revert RevokedSession();
        // check session account approval
        if (EIP1271_MAGIC_VALUE != IERC1271(session.account).isValidSignature(sessionId, session.approval)) revert InvalidSessionApproval();
        // check session signer's signature on hash
        if (!SignatureChecker.isValidSignatureNow(hash, signature, session.signer)) revert InvalidSignature();
    }

    /// @notice Revoke a session to prematurely expire it.
    ///
    /// @dev Without a scope to mitigate, sessions can revoke other sessions.
    ///
    /// @param session The session to revoke
    function revokeSession(Session calldata session) external {
        bytes32 sessionId = keccak256(abi.encode(session));
        if (_revokedSessions[msg.sender][sessionId]) {
            revert RevokedSession();
        }
        _revokedSessions[msg.sender][sessionId] = true;

        emit SessionRevoked(msg.sender, sessionId);
    }

    // TODO: add an `invokeSession` function to enable re-enabling revoked sessions?
}