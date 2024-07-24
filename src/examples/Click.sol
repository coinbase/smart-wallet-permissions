// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import {IPermissionCallable} from "../permissions/CallWithPermission/IPermissionCallable.sol";
import {IOffchainAuthorization} from "../offchain-authorization/IOffchainAuthorization.sol";

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

contract AuthorizedClick is PermissionedClick, IOffchainAuthorization {
    function getRequestAuthorization(bytes32 hash, bytes calldata authData) external view returns (Authorization) {
        if (authData.length != 32) {
            return Authorization.UNAUTHORIZED;
        }
        return abi.decode(authData, (Authorization));
    }
}