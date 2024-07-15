// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import {IPermissionCallable} from "../IPermissionCallable.sol";

abstract contract FriendTechCore {
    event SharesBought(address account, uint256 id, uint256 value);
    event SharesSold(address account, uint256 id, uint256 value);

    function buyShares(uint256 id, uint256 value) public payable {
        emit SharesBought(msg.sender, id, value);
    }
    function sellShares(uint256 id, uint256 value) public payable {
        emit SharesSold(msg.sender, id, value);
    }
}

contract FriendTech is FriendTechCore, IPermissionCallable {

    mapping(bytes32 permissionHash => mapping(address account => uint256 buys)) internal _permissionBuys;
    mapping(bytes32 permissionHash => mapping(address account => uint256 sells)) internal _permissionSells;

    error InvalidCallData();
    error ExceededBuyLimit();
    error ExceededSellLimit();
    error SelectorNotAllowed();

    function callWithPermission(bytes32 permissionHash, bytes calldata permissionArgs, bytes calldata call) external payable returns (bytes memory) {
        bytes4 selector = bytes4(call[:4]);
        bytes memory args = call[4:];
        (uint256 maxBuyAmount, uint256 maxSellAmount) = abi.decode(permissionArgs, (uint256, uint256));

        if (selector == FriendTechCore.sellShares.selector) {
            // selector is buyShares
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            if (value + _permissionBuys[permissionHash][msg.sender] > maxBuyAmount) revert ExceededBuyLimit();
            _permissionBuys[permissionHash][msg.sender] += value;
        } else if (selector == FriendTechCore.sellShares.selector) {
            // selector is sellShares
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            if (value + _permissionSells[permissionHash][msg.sender] > maxSellAmount) revert ExceededSellLimit();
            _permissionSells[permissionHash][msg.sender] += value;
        } else {
            revert SelectorNotAllowed();
        }

        return Address.functionDelegateCall(address(this), call);
    }
}