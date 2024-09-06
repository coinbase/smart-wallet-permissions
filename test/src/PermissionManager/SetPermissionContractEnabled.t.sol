// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {PermissionManager} from "../../../src/PermissionManager.sol";

import {PermissionManagerBase} from "../../base/PermissionManagerBase.sol";

contract SetPermissionContractEnabledTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_setPermissionContractEnabled_revert_notOwner(address sender, address permissionContract, bool enabled)
        public
    {
        vm.assume(permissionContract != address(0));
        vm.assume(sender != owner);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.setPermissionContractEnabled(permissionContract, enabled);
    }

    function test_setPermissionContractEnabled_success_emitsEvent(address permissionContract, bool enabled) public {
        vm.prank(owner);
        vm.expectEmit(address(permissionManager));
        emit PermissionManager.PermissionContractUpdated(permissionContract, enabled);
        permissionManager.setPermissionContractEnabled(permissionContract, enabled);
    }

    function test_setPermissionContractEnabled_success_setsState(address permissionContract, bool enabled) public {
        vm.prank(owner);
        permissionManager.setPermissionContractEnabled(permissionContract, enabled);
        vm.assertEq(permissionManager.isPermissionContractEnabled(permissionContract), enabled);
    }
}
