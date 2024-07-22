// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import {IPermissionCallable} from "../IPermissionCallable.sol";

contract Click {
    event Clicked(address indexed sender);

    function click() public {
        emit Clicked(msg.sender);
    }

}

contract PermissionedClick is Click, IPermissionCallable {
    function callWithPermission(bytes32 /*permissionHash*/, bytes calldata /*permissionArgs*/, bytes calldata call) external payable returns (bytes memory) {
        return Address.functionDelegateCall(address(this), call);
    }
}