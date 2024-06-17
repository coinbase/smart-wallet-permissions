// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title IScopeVerifier
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet)
interface IScopeVerifier {
    function verifyScope(address account, bytes32 hash, bytes32 sessionId, bytes calldata scopeData, bytes calldata dynamicData) external;
}
