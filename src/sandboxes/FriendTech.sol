// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import {ISessionCall} from "../utils/ISessionCall.sol";
import {UserOperationUtils} from "../utils/UserOperationUtils.sol";

abstract contract FriendTechV1 {
    function buyShares(uint256 id, uint256 value) public payable {}
    function sellShares(uint256 id, uint256 value) public payable {}
}

contract FriendTechV2 is FriendTechV1, ISessionCall, UserOperationUtils {

    struct SessionKeyPermissions {
        uint256 maxSellAmount;
        uint256 maxBuyAmount;
    }

    mapping(bytes32 sessionHash => mapping(address account => uint256 buys)) internal _sessionBuys;
    mapping(bytes32 sessionHash => mapping(address account => uint256 sells)) internal _sessionSells;

    function sessionCallUri() external pure returns (string memory) {
        return "https://sessionscan.com/0x";
    }

    function validateSessionCall(address account, bytes32 sessionHash, bytes calldata data, bytes calldata permissionData) external view returns (bool, bytes memory) {
        (bytes4 selector, bytes memory args) = _splitCallData(data);
        (SessionKeyPermissions memory permissions) = abi.decode(permissionData, (SessionKeyPermissions));

        if (selector == 0x00000000) {
            // selector is buyShares
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            require(value + _sessionBuys[sessionHash][account] <= permissions.maxBuyAmount);
            return (true, abi.encode(true, value));
        } else if (selector == 0x11111111) {
            // selector is sellShares
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            require(value + _sessionSells[sessionHash][account] <= permissions.maxSellAmount);
            return (true, abi.encode(false, value));
        } else {
            revert();
        }
    }

    function sessionCall(bytes calldata data) external payable returns (bytes memory) {
        return Address.functionDelegateCall(address(this), data);
    }

    function sessionCallback(bytes32 sessionHash, bytes calldata data) external {
        (bool isBuy, uint256 value) = abi.decode(data, (bool, uint256));
        if (isBuy) {
            _sessionBuys[sessionHash][msg.sender] += value;
        } else {
            _sessionSells[sessionHash][msg.sender] += value;
        }
    }
}