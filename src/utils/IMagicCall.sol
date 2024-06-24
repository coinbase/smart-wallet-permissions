// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IMagicCall {
    function magicCall(bytes calldata data) external;
    function magicCallUri() external view returns (string memory);
}
