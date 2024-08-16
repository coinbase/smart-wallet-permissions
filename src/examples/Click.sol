// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {SignatureChecker} from "openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";

import {PermissionCallable} from "../permissions/PermissionCallable/PermissionCallable.sol";
import {IOffchainAuthorization} from "../policies/OffchainAuthorization/IOffchainAuthorization.sol";

contract Click is Ownable, PermissionCallable, IOffchainAuthorization {
    event Clicked(address indexed account);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function click() public payable {
        emit Clicked(msg.sender);
        // return value back to sender, used for testing native token spend
        msg.sender.call{value: msg.value}("");
    }

    function supportsPermissionedCallSelector(bytes4 /*selector*/ ) public pure override returns (bool) {
        return true;
    }

    function getRequestAuthorization(bytes32 hash, bytes calldata signature) external view returns (Authorization) {
        if (!SignatureChecker.isValidSignatureNow(owner(), hash, signature)) {
            return Authorization.UNVERIFIED;
        } else {
            return Authorization.VERIFIED;
        }
    }
}
