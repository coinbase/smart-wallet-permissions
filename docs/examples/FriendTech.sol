// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PermissionCallable} from "smart-wallet-permissions/mixins/PermissionCallable.sol";

contract FriendTech is PermissionCallable {
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
        return (selector == FriendTech.buyShares.selector || selector == FriendTech.sellShares.selector);
    }
}
