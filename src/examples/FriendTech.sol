// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {SignatureChecker} from "openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";

import {IOffchainAuthorization} from "../offchain-authorization/IOffchainAuthorization.sol";
import {IPermissionCallable} from "../permissions/CallWithPermission/IPermissionCallable.sol";

abstract contract FriendTech {
    event SharesBought(address account, uint256 id, uint256 value);
    event SharesSold(address account, uint256 id, uint256 value);

    function buyShares(uint256 id, uint256 value) public payable {
        emit SharesBought(msg.sender, id, value);
    }

    function sellShares(uint256 id, uint256 value) public payable {
        emit SharesSold(msg.sender, id, value);
    }
}

contract PermissionedFriendTech is FriendTech, IPermissionCallable {
    mapping(bytes32 permissionHash => mapping(address account => uint256 buys)) internal _permissionBuys;
    mapping(bytes32 permissionHash => mapping(address account => uint256 sells)) internal _permissionSells;

    error InvalidCallData();
    error ExceededBuyLimit();
    error ExceededSellLimit();
    error SelectorNotAllowed();

    function callWithPermission(bytes32 permissionHash, bytes calldata permissionArgs, bytes calldata call)
        external
        payable
        returns (bytes memory)
    {
        bytes4 selector = bytes4(call[:4]);
        bytes memory args = call[4:];
        (uint256 maxBuyAmount, uint256 maxSellAmount) = abi.decode(permissionArgs, (uint256, uint256));

        if (selector == FriendTech.sellShares.selector) {
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            if (value + _permissionBuys[permissionHash][msg.sender] > maxBuyAmount) revert ExceededBuyLimit();
            _permissionBuys[permissionHash][msg.sender] += value;
        } else if (selector == FriendTech.sellShares.selector) {
            (, uint256 value) = abi.decode(args, (uint256, uint256));
            if (value + _permissionSells[permissionHash][msg.sender] > maxSellAmount) revert ExceededSellLimit();
            _permissionSells[permissionHash][msg.sender] += value;
        } else {
            revert SelectorNotAllowed();
        }

        return Address.functionDelegateCall(address(this), call);
    }
}

contract AuthorizedFriendTech is PermissionedFriendTech, AccessControl, IOffchainAuthorization {
    function getRequestAuthorization(bytes32 hash, bytes calldata authData) external view returns (Authorization) {
        (address signer, bytes memory signature) = abi.decode(authData, (address, bytes));
        if (!hasRole(keccak256("SIGNER"), signer)) {
            return Authorization.UNAUTHORIZED;
        }
        if (!SignatureChecker.isValidSignatureNow(signer, hash, signature)) {
            return Authorization.UNAUTHORIZED;
        } else {
            return Authorization.AUTHORIZED;
        }
    }
}
