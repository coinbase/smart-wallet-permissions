// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";

import {PermissionManagerBase} from "../../base/PermissionManagerBase.sol";

contract PauseTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_pause_revert_notOwner(address sender) public {
        vm.assume(sender != owner);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.pause();
    }

    function test_pause_revert_alreadyPaused() public {
        vm.startPrank(owner);

        permissionManager.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        permissionManager.pause();
    }

    function test_pause_success_emitsEvent() public {
        vm.startPrank(owner);

        vm.expectEmit(address(permissionManager));
        emit Pausable.Paused(owner);
        permissionManager.pause();
    }

    function test_pause_success() public {
        vm.startPrank(owner);

        permissionManager.pause();
        vm.assertEq(permissionManager.paused(), true);
    }

    function test_unpause_revert_notOwner(address sender) public {
        vm.assume(sender != owner);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.unpause();
    }

    function test_unpause_revert_alreadyUnpaused() public {
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));
        permissionManager.unpause();
    }

    function test_unpause_success_emitsEvent() public {
        vm.startPrank(owner);

        permissionManager.pause();

        vm.expectEmit(address(permissionManager));
        emit Pausable.Unpaused(owner);
        permissionManager.unpause();
    }

    function test_unpause_success_setsState() public {
        vm.startPrank(owner);

        permissionManager.pause();
        permissionManager.unpause();
        vm.assertEq(permissionManager.paused(), false);
    }
}
