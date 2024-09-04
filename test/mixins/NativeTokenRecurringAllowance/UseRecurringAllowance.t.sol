// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {NativeTokenRecurringAllowanceBase} from "./NativeTokenRecurringAllowanceBase.sol";

contract UseRecurringAllowanceTest is Test, NativeTokenRecurringAllowanceBase {
    function setUp() public {}

    function test_useRecurringAllowance_revert_ZeroRecurringAllowance() public {
        revert("unimplemented");
    }

    function test_useRecurringAllowance_revert_BeforeRecurringAllowanceStart() public {
        revert("unimplemented");
    }

    function test_useRecurringAllowance_revert_SpendValueOverflow() public {
        revert("unimplemented");
    }

    function test_useRecurringAllowance_revert_ExceededRecurringAllowance() public {
        revert("unimplemented");
    }

    function test_useRecurringAllowance_success() public {
        revert("unimplemented");
    }

    function test_useRecurringAllowance_success_noSpend() public {
        revert("unimplemented");
    }

    function test_useRecurringAllowance_success_maxAllowance() public {
        revert("unimplemented");
    }

    function test_getRecurringAllowanceUsage_revert_BeforeRecurringAllowanceStart() public {
        revert("unimplemented");
    }

    function test_getRecurringAllowanceUsage_success_currentPeriod() public {
        revert("unimplemented");
    }

    function test_getRecurringAllowanceUsage_success_resetAfterPeriod() public {
        revert("unimplemented");
    }
}
