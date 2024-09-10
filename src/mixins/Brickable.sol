// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

/// @title Brickable
///
/// @notice A last-resort utility to irreversibly brick a contract against an adversarial environment.
///
/// @dev Signature authorization designed to enable brick transactions even if brick authorizer key compromised.
/// @dev Brick message is optionally chain-invariant to enable cross-chain replay if authorizer key becomes unavailable.
///
/// @author Coinbase
contract Brickable {
    /// @notice Immutable entity for authorizing the brick.
    address public immutable brickAuthorizer;

    /// @notice Store if the contract has been bricked or not.
    bool private _bricked;

    /// @notice Immutable hash of the utilizing contract's name.
    bytes32 private immutable nameHash;

    /// @notice Immutable salt for the hash computation to enable cross-chain replay.
    bytes32 private immutable chainInvariantSalt;

    /// @notice
    error InvalidBrickAuthorizer();

    /// @notice Bricked status is enforced.
    error EnforcedBrick();

    /// @notice Brick request chainId is non-zero and not this chain.
    error InvalidChainId();

    /// @notice Brick request is unauthorized.
    error UnauthorizedBrick();

    /// @notice Contract has been irreversibly bricked.
    event Bricked();

    /// @notice Constructor.
    ///
    /// @param authorizer Address of the authorizing entity that can trigger bricks.
    /// @param name String name of the utilizing contract.
    /// @param salt Chain-invariant salt to replace typical chainId+verifyingContract replay protection.
    constructor(address authorizer, string memory name, bytes32 salt) {
        if (authorizer == address(0)) revert InvalidBrickAuthorizer();
        brickAuthorizer = authorizer;
        nameHash = keccak256(bytes(name));
        chainInvariantSalt = salt;
    }

    /// @notice Require modified function to not be bricked.
    modifier whenNotBricked() {
        _requireNotBricked();
        _;
    }

    /// @notice Brick this contract via authorizer signature.
    ///
    /// @dev Signature authorization was chosen because we assume an adversarial environment where authorizer key
    ///      may also be compromised and struggle to submit transactions due to automated draining transactions.
    ///
    /// @param chainId Id for the brick message that allows chain-specificity (non-zero) or chain-invariance (zero).
    /// @param signature Bytes signed over the constant brick message.
    function brick(uint256 chainId, bytes calldata signature) external {
        // early return if already bricked
        if (bricked()) return;

        // check chainId is all chains or this chain
        if (chainId != 0 && chainId != block.chainid) revert InvalidChainId();

        // check if brick signature is authorized
        if (!SignatureCheckerLib.isValidSignatureNow(brickAuthorizer, _eip712Hash(chainId), signature)) {
            revert UnauthorizedBrick();
        }

        _bricked = true;
        emit Bricked();
    }

    /// @notice Read if this contract is bricked.
    ///
    /// @return bricked True if this contract is bricked.
    function bricked() public view returns (bool) {
        return _bricked;
    }

    /// @notice Revert if this contract is bricked.
    function _requireNotBricked() internal view {
        if (bricked()) revert EnforcedBrick();
    }

    /// @notice Compute the constant hash for brick authorization signatures.
    ///
    /// @return hash EIP-712 hash of the brick message.
    function _eip712Hash(uint256 chainId) private view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,uint256 chainId,bytes32 salt)"),
                nameHash,
                chainId,
                chainInvariantSalt
            )
        );
        bytes32 hashStruct = keccak256(abi.encode(keccak256("Brick()")));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, hashStruct));
    }
}
