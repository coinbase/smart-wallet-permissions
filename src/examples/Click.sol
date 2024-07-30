// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import {IOffchainAuthorization} from "../offchain-authorization/IOffchainAuthorization.sol";
import {IPermissionCallable} from "../permissions/AllowedContract/IPermissionCallable.sol";

contract Click {
    event Clicked(address indexed account);

    function click() public {
        emit Clicked(msg.sender);
    }
}

contract PermissionedClick is Click, IPermissionCallable {
    function permissionedCall(bytes calldata call) external payable returns (bytes memory) {
        return Address.functionDelegateCall(address(this), call);
    }
}

contract AuthorizedClick is PermissionedClick, IOffchainAuthorization {
    function getRequestAuthorization(bytes32, /*hash*/ bytes calldata authData) external pure returns (Authorization) {
        if (authData.length != 32) {
            return Authorization.UNAUTHORIZED;
        }
        return abi.decode(authData, (Authorization));
    }
}
