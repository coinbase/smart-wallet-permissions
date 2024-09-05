// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {IPermissionContract} from "../../../src/interfaces/IPermissionContract.sol";
import {NativeTokenRecurringAllowance} from "../../../src/mixins/NativeTokenRecurringAllowance.sol";
import {PermissionCallableAllowedContractNativeTokenRecurringAllowance as PermissionContract} from
    "../../../src/permissions/PermissionCallableAllowedContractNativeTokenRecurringAllowance.sol";

import {PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase as PermissionContractBase} from
    "../../base/PermissionCallableAllowedContractNativeTokenRecurringAllowanceBase.sol";

contract InitializePermissionTest is Test, PermissionContractBase {
    function setUp() public {
        _initializePermissionContract();
    }

    function test_initializePermission_revert_decodingError(
        address account,
        bytes32 permissionHash,
        bytes memory permissionValues
    ) public {
        vm.expectRevert();
        permissionContract.initializePermission(account, permissionHash, permissionValues);
    }

    function test_initializePermission_revert_InvalidInitializePermissionSender(
        address sender,
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract
    ) public {
        vm.assume(sender != address(permissionManager));
        vm.assume(start > 0);
        vm.assume(period > 0);

        vm.prank(sender);

        vm.expectRevert(abi.encodeWithSelector(IPermissionContract.InvalidInitializePermissionSender.selector, sender));
        permissionContract.initializePermission(
            account, permissionHash, abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );
    }

    function test_initializePermission_success(
        address account,
        bytes32 permissionHash,
        uint48 start,
        uint48 period,
        uint160 allowance,
        address allowedContract
    ) public {
        vm.assume(start > 0);
        vm.assume(period > 0);

        vm.prank(address(permissionManager));

        permissionContract.initializePermission(
            account, permissionHash, abi.encode(_createPermissionValues(start, period, allowance, allowedContract))
        );

        NativeTokenRecurringAllowance.RecurringAllowance memory recurringAllowance =
            permissionContract.getRecurringAllowance(account, permissionHash);
        assertEq(recurringAllowance.start, start);
        assertEq(recurringAllowance.period, period);
        assertEq(recurringAllowance.allowance, allowance);
    }
}
