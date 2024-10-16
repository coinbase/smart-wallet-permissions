// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SpendPermissionManager} from "../../../src/SpendPermissionManager.sol";

import {SpendPermissionManagerBase} from "../../base/SpendPermissionManagerBase.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

contract PermitTest is SpendPermissionManagerBase {
    function setUp() public {
        _initializeSpendPermissionManager();
        vm.prank(owner);
        account.addOwnerAddress(address(mockSpendPermissionManager));
    }

    function test_permit_revert_unauthorizedSpendPermission(
        uint128 invalidPk,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(invalidPk != 0);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        bytes memory invalidSignature = _signSpendPermission(spendPermission, invalidPk, 0);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.UnauthorizedSpendPermission.selector));
        mockSpendPermissionManager.permit(spendPermission, invalidSignature);
    }

    function test_permit_revert_invalidStartEnd(
        address spender,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start >= end);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: spender,
            token: NATIVE_TOKEN,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        bytes memory signature = _signSpendPermission(spendPermission, ownerPk, 0);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.InvalidStartEnd.selector, start, end));
        mockSpendPermissionManager.permit(spendPermission, signature);
    }

    function test_permit_revert_zeroPeriod(address spender, uint48 start, uint48 end, uint160 allowance) public {
        vm.assume(start < end);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: spender,
            token: NATIVE_TOKEN,
            start: start,
            end: end,
            period: 0,
            allowance: allowance
        });

        bytes memory signature = _signSpendPermission(spendPermission, ownerPk, 0);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.ZeroPeriod.selector));
        mockSpendPermissionManager.permit(spendPermission, signature);
    }

    function test_permit_revert_zeroAllowance(address spender, uint48 start, uint48 end, uint48 period) public {
        vm.assume(start < end);
        vm.assume(period > 0);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: spender,
            token: NATIVE_TOKEN,
            start: start,
            end: end,
            period: period,
            allowance: 0
        });

        bytes memory signature = _signSpendPermission(spendPermission, ownerPk, 0);
        vm.expectRevert(abi.encodeWithSelector(SpendPermissionManager.ZeroAllowance.selector));
        mockSpendPermissionManager.permit(spendPermission, signature);
    }

    function test_permit_success_isApproved(
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        bytes memory signature = _signSpendPermission(spendPermission, ownerPk, 0);
        mockSpendPermissionManager.permit(spendPermission, signature);
        vm.assertTrue(mockSpendPermissionManager.isApproved(spendPermission));
    }

    function test_permit_success_emitsEvent(
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);

        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: address(account),
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });

        bytes memory signature = _signSpendPermission(spendPermission, ownerPk, 0);
        vm.expectEmit(address(mockSpendPermissionManager));
        emit SpendPermissionManager.SpendPermissionApproved({
            hash: mockSpendPermissionManager.getHash(spendPermission),
            account: address(account),
            spendPermission: spendPermission
        });
        mockSpendPermissionManager.permit(spendPermission, signature);
    }

    function test_permit_success_erc6492SignaturePreDeploy(
        uint128 ownerPk,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(ownerPk != 0);
        // generate the counterfactual address for the account
        address ownerAddress = vm.addr(ownerPk);
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(ownerAddress);
        address counterfactualAccount = mockCoinbaseSmartWalletFactory.getAddress(owners, 0);

        // create a 6492-compliant signature for the spend permission
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: counterfactualAccount,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        bytes memory signature = _signSpendPermission6492(spendPermission, ownerPk, 0, owners);
        // verify that the account isn't deployed yet
        vm.assertEq(counterfactualAccount.code.length, 0);

        // submit the spend permission with the signature, see permit succeed
        mockSpendPermissionManager.permit(spendPermission, signature);

        // verify that the account is now deployed (has code) and that a call to isValidSignature returns true
        vm.assertGt(counterfactualAccount.code.length, 0);
        vm.assertTrue(mockSpendPermissionManager.isApproved(spendPermission));
    }

    function test_permit_success_erc6492SignatureAlreadyDeployed(
        uint128 ownerPk,
        address spender,
        address token,
        uint48 start,
        uint48 end,
        uint48 period,
        uint160 allowance
    ) public {
        vm.assume(start > 0);
        vm.assume(start < end);
        vm.assume(period > 0);
        vm.assume(allowance > 0);
        vm.assume(ownerPk != 0);
        // generate the counterfactual address for the account
        address ownerAddress = vm.addr(ownerPk);
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(ownerAddress);
        address counterfactualAccount = mockCoinbaseSmartWalletFactory.getAddress(owners, 0);
        // deploy the account already
        mockCoinbaseSmartWalletFactory.createAccount(owners, 0);
        // create a 6492-compliant signature for the spend permission
        SpendPermissionManager.SpendPermission memory spendPermission = SpendPermissionManager.SpendPermission({
            account: counterfactualAccount,
            spender: spender,
            token: token,
            start: start,
            end: end,
            period: period,
            allowance: allowance
        });
        bytes memory signature = _signSpendPermission6492(spendPermission, ownerPk, 0, owners);
        // verify that the account is already deployed
        vm.assertGt(counterfactualAccount.code.length, 0);

        // submit the spend permission with the signature, see permit succeed
        mockSpendPermissionManager.permit(spendPermission, signature);
        vm.assertTrue(mockSpendPermissionManager.isApproved(spendPermission));
    }
}
