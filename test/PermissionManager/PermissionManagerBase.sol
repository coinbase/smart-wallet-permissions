// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {MockCoinbaseSmartWallet} from "../mocks/MockCoinbaseSmartWallet.sol";

import {PermissionManager} from "../../src/PermissionManager.sol";
import {MockPermissionContract} from "../mocks/MockPermissionContract.sol";

contract PermissionManagerBase is Test {
    PermissionManager permissionManager;
    uint256 ownerPk = uint256(keccak256("owner"));
    address owner = vm.addr(ownerPk);
    uint256 cosignerPk = uint256(keccak256("cosigner"));
    address cosigner = vm.addr(cosignerPk);
    uint256 permmissionSignerPk = uint256(keccak256("permissionSigner"));
    address permissionSigner = vm.addr(permmissionSignerPk);
    MockCoinbaseSmartWallet account;
    MockPermissionContract successPermissionContract;
    MockPermissionContract failPermissionContract;

    function _initializePermissionManager() internal {
        permissionManager = new PermissionManager(owner, cosigner);
        account = new MockCoinbaseSmartWallet();
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(owner);
        account.initialize(owners);
        successPermissionContract = new MockPermissionContract(false);
        failPermissionContract = new MockPermissionContract(true);
    }

    function _createPermission() internal returns (PermissionManager.Permission memory) {
        return PermissionManager.Permission({
            account: address(account),
            chainId: block.chainid,
            expiry: type(uint48).max,
            signer: abi.encode(cosigner),
            permissionContract: address(successPermissionContract),
            permissionValues: hex"",
            verifyingContract: address(permissionManager),
            approval: hex""
        });
    }
}
