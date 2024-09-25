// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {RecurringAllowanceManager} from "../../../../src/RecurringAllowanceManager.sol";

import {Base} from "../../base/Base.sol";

contract RecurringAllowanceManagerTest is Test, Base {
    address public constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    RecurringAllowanceManager manager;

    function setUp() public {
        _initialize();

        manager = new RecurringAllowanceManager();

        vm.prank(owner);
        account.addOwnerAddress(address(manager));
    }

    function tes_approve() public {
        RecurringAllowanceManager.RecurringAllowance memory recurringAllowance = _createRecurringAllowance();

        vm.prank(address(account));
        manager.approve(recurringAllowance);
    }

    function test_withdraw() public {
        RecurringAllowanceManager.RecurringAllowance memory recurringAllowance = _createRecurringAllowance();

        vm.prank(address(account));
        manager.approve(recurringAllowance);

        vm.deal(address(account), 1 ether);
        vm.prank(owner);
        manager.withdraw(recurringAllowance, 1 ether / 2);
    }

    function _createRecurringAllowance() internal view returns (RecurringAllowanceManager.RecurringAllowance memory) {
        return RecurringAllowanceManager.RecurringAllowance({
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
