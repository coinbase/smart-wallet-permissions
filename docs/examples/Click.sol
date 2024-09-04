// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PermissionCallable} from "smart-wallet-permissions/mixins/PermissionCallable.sol";

contract Click is PermissionCallable {
    event Clicked(address indexed account);

    function click() public payable {
        emit Clicked(msg.sender);
        // return value back to sender, used for testing native token spend
        (bool success,) = msg.sender.call{value: msg.value}("");
        require(success);
    }

    function supportsPermissionedCallSelector(bytes4 selector) public pure override returns (bool) {
        return selector == Click.click.selector;
    }
}
