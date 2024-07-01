// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {CoinbaseSmartWallet, UserOperation, SignatureCheckerLib, WebAuthn} from "smart-wallet/CoinbaseSmartWallet.sol";

import {SignatureChecker} from "./utils/SignatureChecker.sol";
import {IPermissionContract} from "./permissions/IPermissionContract.sol";

/// @notice Experimental implementation of session management within CoinbaseSmartWallet.
contract SmartWallet is CoinbaseSmartWallet {
    /// @notice A time-bound provision of scoped account control to another signer.
    struct Session {
        address account;
        uint256 chainId;
        bytes signer; // supports EOA, smart contracts, and passkeys
        uint40 expiry;
        address permissionContract;
        bytes permissionData;
        bytes approval; // signature from an account owner proving a session is valid
    }

    /// @notice Session account does not match currently authentication sender.
    error InvalidSessionAccount();

    /// @notice Session chain is not agnositc and not this chain.
    error InvalidSessionChain();

    /// @notice Session is revoked.
    error RevokedSession();
    
    /// @notice SessionApproval is invalid
    error InvalidSessionApproval();

    /// @notice Signature from session signer does not match hash.
    error InvalidSignature();

    /// @notice Session permission check failed
    error InvalidSessionPermission();

    /// @notice Session was revoked prematurely by account.
    ///
    /// @param account The smart contract account the session controlled.
    /// @param sessionHash The unique hash representing the session.
    event SessionRevoked(address indexed account, bytes32 indexed sessionHash);
    
    /// @dev keying storage by account in deepest mapping enables us to pass 4337 storage access limitations
    /// TODO: move to 7201 storage
    mapping(bytes32 sessionHash => bool revoked) internal _revokedSessions;

    bytes32 constant public SESSION_MAGIC_VALUE = 0x7777777777777777777777777777777777777777777777777777777777777777;
    bytes4 constant public EIP1271_MAGIC_VALUE = 0x1626ba7e;

    function _validateSession(bytes32 hash, Session memory session, bytes memory signature, bytes memory requestData) internal view returns (uint256) {
        bytes32 sessionHash = hashSession(session);

        // check account matches this
        if (session.account != address(this)) revert InvalidSessionAccount();
        // check chainId is agnostic or this chain
        if (session.chainId != block.chainid) revert InvalidSessionChain();
        // check session not revoked
        if (_revokedSessions[sessionHash]) revert RevokedSession();
        // check session account approval
        if (EIP1271_MAGIC_VALUE != IERC1271(address(this)).isValidSignature(sessionHash, session.approval)) revert InvalidSessionApproval();
        // check session signer's signature on hash
        if (!SignatureChecker.isValidSignatureNow(hash, signature, session.signer)) revert InvalidSignature();

        // validate permission-specific logic, returns validationData for time expiry
        // TODO: take session.expiry into account for the validUntil part of validationData
        return IPermissionContract(session.permissionContract).validatePermission(address(this), hash, sessionHash, session.permissionData, requestData);
    }

    function hashSession(Session memory session) public pure returns (bytes32) {
        return keccak256(abi.encode(
            session.account,
            session.chainId,
            keccak256(session.signer),
            session.expiry,
            session.permissionContract,
            keccak256(session.permissionData)
        ));
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        virtual
        override
        onlyEntryPoint
        payPrefund(missingAccountFunds)
        returns (uint256 validationData)
    {
        uint256 key = userOp.nonce >> 64;

        if (bytes4(userOp.callData) == this.executeWithoutChainIdValidation.selector) {
            userOpHash = getUserOpHashWithoutChainId(userOp);
            if (key != REPLAYABLE_NONCE_KEY) {
                revert InvalidNonceKey(key);
            }
        } else {
            if (key == REPLAYABLE_NONCE_KEY) {
                revert InvalidNonceKey(key);
            }
        }

        // check signature prefix against magic value to activate session logic
        if (bytes32(userOp.signature) == SESSION_MAGIC_VALUE) {
            (/*bytes32 magicValue*/, Session memory session, bytes memory signature) = abi.decode(userOp.signature, (bytes32, Session, bytes));
            return _validateSession(userOpHash, session, signature, abi.encode(userOp));
        }

        // Return 0 if the recovered address matches the owner.
        if (_isValidSignature(userOpHash, userOp.signature)) {
            return 0;
        }

        // Else return 1
        return 1;
    }

    function _isValidSignature(bytes32 hash, bytes calldata signature) internal view virtual override returns (bool) {
        SignatureWrapper memory sigWrapper = abi.decode(signature, (SignatureWrapper));

        // check ownerIndex against magic value to activate session logic
        if (bytes32(sigWrapper.ownerIndex) == SESSION_MAGIC_VALUE) {
            (Session memory session, bytes memory sessionSignature, bytes memory requestData) = abi.decode(sigWrapper.signatureData, (Session, bytes, bytes));
            uint256 validationData = _validateSession(hash, session, sessionSignature, requestData);
            if (validationData != 0) revert InvalidSessionPermission();
        }

        bytes memory ownerBytes = ownerAtIndex(sigWrapper.ownerIndex);
        if (ownerBytes.length == 32) {
            if (uint256(bytes32(ownerBytes)) > type(uint160).max) {
                // technically should be impossible given owners can only be added with
                // addOwnerAddress and addOwnerPublicKey, but we leave incase of future changes.
                revert InvalidEthereumAddressOwner(ownerBytes);
            }

            address owner;
            assembly ("memory-safe") {
                owner := mload(add(ownerBytes, 32))
            }

            return SignatureCheckerLib.isValidSignatureNow(owner, hash, sigWrapper.signatureData);
        }

        if (ownerBytes.length == 64) {
            (uint256 x, uint256 y) = abi.decode(ownerBytes, (uint256, uint256));

            WebAuthn.WebAuthnAuth memory auth = abi.decode(sigWrapper.signatureData, (WebAuthn.WebAuthnAuth));

            return WebAuthn.verify({challenge: abi.encode(hash), requireUV: false, webAuthnAuth: auth, x: x, y: y});
        }

        revert InvalidOwnerBytesLength(ownerBytes);
    }
}