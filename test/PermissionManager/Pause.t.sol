// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";

import {PermissionManagerBase} from "./PermissionManagerBase.sol";

contract PauseTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_pause_revert_unauthorized(address sender) public {
        vm.assume(sender != owner);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.pause();
    }

    function test_pause_revert_paused() public {
        vm.startPrank(owner);

        permissionManager.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        permissionManager.pause();
    }

    function test_pause_success() public {
        vm.startPrank(owner);

        permissionManager.pause();
        vm.assertEq(permissionManager.paused(), true);
    }

    function test_unpause_revert_unauthorized(address sender) public {
        vm.assume(sender != owner);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.unpause();
    }

    function test_unpause_revert_unpaused() public {
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));
        permissionManager.unpause();
    }

    function test_unpause_success() public {
        vm.startPrank(owner);

        permissionManager.pause();
        permissionManager.unpause();
        vm.assertEq(permissionManager.paused(), false);
    }
}
