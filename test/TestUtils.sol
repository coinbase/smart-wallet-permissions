// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {CoinbaseSmartWalletFactory} from "smart-wallet/CoinbaseSmartWalletFactory.sol";

import {IPermissionContract} from "../src/permissions/IPermissionContract.sol";

contract TestUtils {
    CoinbaseSmartWalletFactory walletFactory;

    function setUpSmartWallet() public {
        address implementation = address(new CoinbaseSmartWallet());
        walletFactory = new CoinbaseSmartWalletFactory(implementation);
    }

    function newSmartWallet() public returns (address) {
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(address(0));
        return address(walletFactory.createAccount(owners, 0));
    }
}
