// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {SignatureChecker} from "openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";

import {IOffchainAuthorization} from "../offchain-authorization/IOffchainAuthorization.sol";
import {PermissionCallable} from "../permissions/AllowedContract/PermissionCallable.sol";

abstract contract FriendTech is PermissionCallable {
    event SharesBought(address account, uint256 id, uint256 value);
    event SharesSold(address account, uint256 id, uint256 value);
    event SharesBurnt(address account, uint256 id, uint256 value);

    function buyShares(uint256 id, uint256 value) public payable permissionCallable {
        emit SharesBought(msg.sender, id, value);
    }

    function sellShares(uint256 id, uint256 value) public permissionCallable {
        emit SharesSold(msg.sender, id, value);
    }

    function burnShares(uint256 id, uint256 value) public {
        emit SharesBurnt(msg.sender, id, value);
    }
}

contract AuthorizedFriendTech is FriendTech, AccessControl, IOffchainAuthorization {
    function getRequestAuthorization(bytes32 hash, bytes calldata authData) external view returns (Authorization) {
        (address signer, bytes memory signature) = abi.decode(authData, (address, bytes));
        if (!hasRole(keccak256("SIGNER"), signer)) {
            return Authorization.UNAUTHORIZED;
        }
        if (!SignatureChecker.isValidSignatureNow(signer, hash, signature)) {
            return Authorization.UNAUTHORIZED;
        } else {
            return Authorization.VERIFIED;
        }
    }
}
