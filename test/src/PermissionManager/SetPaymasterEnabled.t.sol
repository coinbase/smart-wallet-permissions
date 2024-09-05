// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {PermissionManagerBase} from "../../base/PermissionManagerBase.sol";

contract SetPaymasterEnabledTest is Test, PermissionManagerBase {
    function setUp() public {
        _initializePermissionManager();
    }

    function test_setPaymasterEnabled_revert_notOwner(address sender, address paymaster, bool enabled) public {
        vm.assume(paymaster != address(0));
        vm.assume(sender != owner);
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        permissionManager.setPaymasterEnabled(paymaster, enabled);
    }

    function test_setPaymasterEnabled_success(address paymaster, bool enabled) public {
        vm.assume(paymaster != address(0));
        vm.prank(owner);
        permissionManager.setPaymasterEnabled(paymaster, enabled);
        vm.assertEq(permissionManager.isPaymasterEnabled(paymaster), enabled);
    }
}
