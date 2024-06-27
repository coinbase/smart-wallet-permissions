// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ISessionCall {
    function sessionCallUri() external view returns (string memory);
    function validateSessionCall(address account, bytes32 sessionHash, bytes calldata data, bytes calldata permissionData) external view returns (bool requireCallback, bytes calldata allbackContext);
    function sessionCall(bytes calldata data) external payable returns (bytes memory);
    function sessionCallback(bytes32 sessionHash, bytes calldata data) external;
}
