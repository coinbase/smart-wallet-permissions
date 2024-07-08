// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IPermissionCallable {
    function callWithPermission(bytes32 permissionHash, bytes calldata permissionData, bytes calldata call) external payable returns (bytes memory);
}
