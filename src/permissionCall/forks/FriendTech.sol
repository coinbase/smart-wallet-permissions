// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import {IPermissionCall} from "../IPermissionCall.sol";
import {UserOperationUtils} from "../../utils/UserOperationUtils.sol";

abstract contract FriendTechV1 {
    event SharesBought(address account, uint256 id, uint256 value);
    event SharesSold(address account, uint256 id, uint256 value);

    function buyShares(uint256 id, uint256 value) public payable {
        emit SharesBought(msg.sender, id, value);
    }
    function sellShares(uint256 id, uint256 value) public payable {
        emit SharesSold(msg.sender, id, value);
    }
}

contract FriendTechV2 is FriendTechV1, IPermissionCall, UserOperationUtils {

    mapping(bytes32 permissionHash => mapping(address account => uint256 buys)) internal _permissionBuys;
    mapping(bytes32 permissionHash => mapping(address account => uint256 sells)) internal _permissionSells;

    function permissionCall(bytes32 permissionHash, bytes calldata permissionData, bytes calldata call) external payable returns (bytes memory) {
        (bytes4 selector, bytes memory args) = _splitCallData(call);
        (uint256 maxBuyAmount, uint256 maxSellAmount) = abi.decode(permissionData, (uint256, uint256));

        if (selector == 0xbeebc5da) {
            // selector is buyShares
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            require(value + _permissionBuys[permissionHash][msg.sender] <= maxBuyAmount);
            _permissionBuys[permissionHash][msg.sender] += value;
        } else if (selector == 0x2279a970) {
            // selector is sellShares
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            require(value + _permissionSells[permissionHash][msg.sender] <= maxSellAmount);
            _permissionSells[permissionHash][msg.sender] += value;
        } else {
            revert();
        }

        return Address.functionDelegateCall(address(this), call);
    }
}