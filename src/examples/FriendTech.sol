// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {SignatureChecker} from "openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";

import {PermissionCallable} from "../permissions/NativeTokenRollingSpendLimit/PermissionCallable.sol";
import {IOffchainAuthorization} from "../policies/OffchainAuthorization/IOffchainAuthorization.sol";

interface IFriendTech {
    function buyShares(uint256 id, uint256 value) external payable;
    function sellShares(uint256 id, uint256 value) external;
    function transferClub(uint256 id, address newOwner) external;
}

contract FriendTech is IFriendTech, PermissionCallable, Multicall {
    event SharesBought(address account, uint256 id, uint256 value);
    event SharesSold(address account, uint256 id, uint256 value);
    event ClubTransferred(uint256 id, address newOwner);

    function buyShares(uint256 id, uint256 value) public payable {
        emit SharesBought(msg.sender, id, value);
    }

    function sellShares(uint256 id, uint256 value) public {
        emit SharesSold(msg.sender, id, value);
    }

    function transferClub(uint256 id, address newOwner) public {
        emit ClubTransferred(id, newOwner);
    }

    function supportsPermissionedCallSelector(bytes4 selector) public pure override returns (bool) {
        return (selector == IFriendTech.buyShares.selector || selector == IFriendTech.sellShares.selector);
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
