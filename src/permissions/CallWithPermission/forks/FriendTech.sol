// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import {IPermissionCallable} from "../IPermissionCallable.sol";

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

contract FriendTechV2 is FriendTechV1, IPermissionCallable {

    mapping(bytes32 permissionHash => mapping(address account => uint256 buys)) internal _permissionBuys;
    mapping(bytes32 permissionHash => mapping(address account => uint256 sells)) internal _permissionSells;

    error InvalidCallData();
    error ExceededBuyLimit();
    error ExceededSellLimit();
    error SelectorNotAllowed();

    function callWithPermission(bytes32 permissionHash, bytes calldata permissionData, bytes calldata call) external payable returns (bytes memory) {
        (bytes4 selector, bytes memory args) = _splitCallData(call);
        (uint256 maxBuyAmount, uint256 maxSellAmount) = abi.decode(permissionData, (uint256, uint256));

        if (selector == 0xbeebc5da) {
            // selector is buyShares
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            if (value + _permissionBuys[permissionHash][msg.sender] > maxBuyAmount) revert ExceededBuyLimit();
            _permissionBuys[permissionHash][msg.sender] += value;
        } else if (selector == 0x2279a970) {
            // selector is sellShares
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            if (value + _permissionSells[permissionHash][msg.sender] > maxSellAmount) revert ExceededSellLimit();
            _permissionSells[permissionHash][msg.sender] += value;
        } else {
            revert SelectorNotAllowed();
        }

        return Address.functionDelegateCall(address(this), call);
    }

    /// @notice split encoded function call into selector and arguments
    function _splitCallData(bytes memory callData) internal pure returns (bytes4 selector, bytes memory args) {
        if (callData.length <= 4) revert InvalidCallData();
        bytes memory trimmed = new bytes(callData.length - 4);
        for (uint i = 4; i < callData.length; i++) {
            trimmed[i - 4] = callData[i];
        }
        return (bytes4(callData), trimmed);
    }
}