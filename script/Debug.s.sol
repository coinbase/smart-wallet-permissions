// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {CoinbaseSmartWalletFactory} from "smart-wallet/CoinbaseSmartWalletFactory.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

// forge script Debug --broadcast -vvvv
contract Debug is Script {
    address public constant OWNER = 0x6EcB18183838265968039955F1E8829480Db5329; // dev wallet
    address public constant FACTORY = 0x0BA5ED0c6AA8c49038F819E587E2633c4A9F428a;
    address public constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function run() public {
        vm.startBroadcast();

        vm.stopBroadcast();
    }

    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
