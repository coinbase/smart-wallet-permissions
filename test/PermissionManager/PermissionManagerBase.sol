// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {PermissionManager} from "../../src/PermissionManager.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

contract PermissionManagerBase is Test {
    CoinbaseSmartWallet public smartWallet;
    PermissionManager public permissionManager;
    address owner = address(69420);
    uint256 cosignerPrivateKey = 0xa11ce;
    address cosigner = vm.addr(cosignerPrivateKey);
    address paymaster = address(0xbeef);

    function setUp() public virtual {
        smartWallet = new CoinbaseSmartWallet();
        permissionManager = new PermissionManager(owner, cosigner);
    }
}
