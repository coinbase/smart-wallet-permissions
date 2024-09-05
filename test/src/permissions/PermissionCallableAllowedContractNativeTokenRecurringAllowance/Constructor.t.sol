// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionCallableAllowedContractNativeTokenRecurringAllowance as PermissionContract} from
    "../../../../src/permissions/PermissionCallableAllowedContractNativeTokenRecurringAllowance.sol";

import {PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase as PermissionContractBase} from
    "../../../base/PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase.sol";

contract ConstructorTest is Test, PermissionContractBase {
    function setUp() public {}

    function test_constructor_revert_zeroPermissionManager(address magicSpend) public {
        address permissionManager = address(0);
        vm.assume(magicSpend != address(0));

        vm.expectRevert(PermissionContract.ZeroAddress.selector);
        new PermissionContract(permissionManager, magicSpend);
    }

    function test_constructor_revert_zeroMagicSpend(address permissionManager) public {
        vm.assume(permissionManager != address(0));
        address magicSpend = address(0);

        vm.expectRevert(PermissionContract.ZeroAddress.selector);
        new PermissionContract(permissionManager, magicSpend);
    }

    function test_constructor_success(address permissionManager, address magicSpend) public {
        vm.assume(permissionManager != address(0) && magicSpend != address(0));
        PermissionContract permissionContract = new PermissionContract(permissionManager, magicSpend);
        vm.assertEq(permissionContract.permissionManager(), permissionManager);
        vm.assertEq(permissionContract.magicSpend(), magicSpend);
    }
}
