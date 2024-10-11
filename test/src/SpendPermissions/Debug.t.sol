// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {SpendPermissions} from "../../../src/SpendPermissions.sol";

import {Base} from "../../base/Base.sol";

contract DebugTest is Test, Base {
    address public constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    SpendPermissions spendPermissions;

    function setUp() public {
        _initialize();

        spendPermissions = new SpendPermissions();

        vm.prank(owner);
        account.addOwnerAddress(address(spendPermissions));
    }

    function test_approve() public {
        SpendPermissions.RecurringAllowance memory recurringAllowance = _createRecurringAllowance();

        vm.prank(address(account));
        spendPermissions.approve(recurringAllowance);
    }

    function test_withdraw(address recipient) public {
        assumePayable(recipient);
        SpendPermissions.RecurringAllowance memory recurringAllowance = _createRecurringAllowance();

        vm.prank(address(account));
        spendPermissions.approve(recurringAllowance);

        vm.deal(address(account), 1 ether);
        vm.prank(owner);
        spendPermissions.withdraw(recurringAllowance, recipient, 1 ether / 2);
    }

    function _createRecurringAllowance() internal view returns (SpendPermissions.RecurringAllowance memory) {
        return SpendPermissions.RecurringAllowance({
            account: address(account),
            spender: owner,
            token: ETHER,
            start: 0,
            end: 1758791693, // 1 year from now
            period: 86400, // 1 day
            allowance: 1 ether
        });
    }
}
