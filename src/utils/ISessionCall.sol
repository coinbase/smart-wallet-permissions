// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ISessionCall {
    function validateSessionCall(bytes calldata data, bytes calldata permissionData) external view returns (uint256 validationData);
    function sessionCall(bytes calldata data) external;
    function sessionCallUri() external view returns (string memory);
}
