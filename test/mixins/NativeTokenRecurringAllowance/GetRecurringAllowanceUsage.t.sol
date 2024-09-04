// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {NativeTokenRecurringAllowance} from "../../../src/mixins/NativeTokenRecurringAllowance.sol";

import {NativeTokenRecurringAllowanceBase} from "./NativeTokenRecurringAllowanceBase.sol";

contract GetRecurringAllowanceUsageTest is Test, NativeTokenRecurringAllowanceBase {
    function setUp() public {
        _initializeNativeTokenRecurringAllowance();
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
