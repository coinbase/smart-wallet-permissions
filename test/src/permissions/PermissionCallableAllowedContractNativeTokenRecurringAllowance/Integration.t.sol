// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase as PermissionContractBase} from
    "../../../base/PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase.sol";

contract IntegrationTest is Test, PermissionContractBase {
    function setUp() public {}
}
