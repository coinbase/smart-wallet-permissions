// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {CoinbaseSmartWallet, UserOperation, SignatureCheckerLib, WebAuthn} from "smart-wallet/CoinbaseSmartWallet.sol";

import {SignatureChecker} from "./utils/SignatureChecker.sol";
import {IPermissionContract} from "./permissions/IPermissionContract.sol";

contract SmartWallet is CoinbaseSmartWallet {
    /// @notice A time-bound provision of scoped account control to another signer.
    struct Session {
        address account;
        bytes approval;
        bytes signer;
        address permissionContract;
        bytes permissionData;
        uint40 expiresAt;
        // TODO: consider EIP-712 format instead
        uint256 chainId; // prevent replay on other chains
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

    function _validateSession(bytes32 hash, bytes32 sessionHash, Session memory session, bytes memory signature) internal view {
        // check chainId is agnostic or this chain
        if (session.chainId != block.chainid) revert InvalidSessionChain();
        // check verifyingContract is SessionManager
        if (session.verifyingContract != address(this)) revert InvalidSessionVerifyingContract();
        // check account matches this
        if (session.account != address(this)) revert InvalidSessionAccount();
        // check session not expired
        /// TODO: return as validation data instead
        if (session.expiresAt < block.timestamp) revert ExpiredSession();
        // check session not revoked
        if (_revokedSessions[sessionHash]) revert RevokedSession();
        // check session account approval
        /// @dev EIP1271_MAGIC_VALUE = 0x1626ba7e 
        if (bytes4(0x1626ba7e) != IERC1271(address(this)).isValidSignature(sessionHash, session.approval)) revert InvalidSessionApproval();
        // check session signer's signature on hash
        if (!SignatureChecker.isValidSignatureNow(hash, signature, session.signer)) revert InvalidSignature();
    }

    /// @dev mismatch of v0.6 UserOperation vs. v0.7 PackedUserOperation
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
        if (bytes32(userOp.signature) == 0x7777777777777777777777777777777777777777777777777777777777777777) {
            (/*bytes32 magicValue*/, Session memory session, bytes memory signature) = abi.decode(userOp.signature, (bytes32, Session, bytes));
            bytes32 sessionHash = keccak256(abi.encode(session));
            _validateSession(userOpHash, sessionHash, session, signature);
            // validate permission-specific logic, returns validationData for time expiry
            return IPermissionContract(session.permissionContract).validatePermissions(userOpHash, sessionHash, session.permissionData, abi.encode(userOp));
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
        if (bytes32(sigWrapper.ownerIndex) == 0x7777777777777777777777777777777777777777777777777777777777777777) {
            (Session memory session, bytes memory sessionSignature, bytes memory requestData) = abi.decode(sigWrapper.signatureData, (Session, bytes, bytes));
            bytes32 sessionHash = keccak256(abi.encode(session));
            _validateSession(hash, sessionHash, session, sessionSignature);
            // validate permission-specific logic, returns validationData for time expiry
            uint256 validationData = IPermissionContract(session.permissionContract).validatePermissions(hash, sessionHash, session.permissionData, requestData);
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