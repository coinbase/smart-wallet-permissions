// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {PermissionManager, PermissionManagerBase} from "./PermissionManagerBase.sol";

contract RenounceOwnershipTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_renounceOwnership_revert_notOwner(address sender) public {
        vm.assume(sender != owner);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.renounceOwnership();
    }

    function test_renounceOwnership_revert_CannotRenounceOwnership() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(PermissionManager.CannotRenounceOwnership.selector));
        permissionManager.renounceOwnership();
    }
}
