// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissionManager} from "../../../../src/SpendPermissionManager.sol";

import {Base} from "../../base/Base.sol";

contract DebugTest is Test, Base {
    address public constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    SpendPermissionManager manager;

    function setUp() public {
        _initialize();

        manager = new SpendPermissionManager();

        vm.prank(owner);
        account.addOwnerAddress(address(manager));
    }

    function test_approve() public {
        SpendPermissionManager.SpendPermission memory spendPermission = _createSpendPermission();

        vm.prank(address(account));
        manager.approveSpendPermission(spendPermission);
    }

    function test_spend(address recipient) public {
        vm.assume(recipient != address(manager));
        SpendPermissionManager.SpendPermission memory spendPermission = _createSpendPermission();

        vm.prank(address(account));
        manager.approveSpendPermission(spendPermission);

        vm.deal(address(account), 1 ether);
        vm.prank(owner);
        manager.spend(spendPermission, recipient, 1 ether / 2);
    }

    function _createSpendPermission() internal view returns (SpendPermissionManager.SpendPermission memory) {
        return SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: owner,
            token: ETHER,
            start: 0,
            end: 1758791693, // 1 year from now
            period: 86400, // 1 day
            amountPerPeriod: 1 ether
        });
    }
}
