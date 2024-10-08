// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {CoinbaseSmartWalletFactory} from "smart-wallet/CoinbaseSmartWalletFactory.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

import {PermissionManager} from "../src/PermissionManager.sol";
import {SpendPermissions} from "../src/SpendPermissions.sol";
import {PermissionCallableAllowedContractNativeTokenRecurringAllowance as PermissionContract} from
    "../src/permissions/PermissionCallableAllowedContractNativeTokenRecurringAllowance.sol";

// forge script Debug --broadcast -vvvv
contract Debug is Script {
    /// @dev Deployment address consistent across chains
    ///      https://github.com/coinbase/magic-spend/releases/tag/v1.0.0
    address public constant MAGIC_SPEND = 0x011A61C07DbF256A68256B1cB51A5e246730aB92;
    address public constant OWNER = 0x6EcB18183838265968039955F1E8829480Db5329; // dev wallet
    address public constant OWNER_2 = 0x0BFc799dF7e440b7C88cC2454f12C58f8a29D986; // work wallet
    address public constant COSIGNER = 0xAda9897F517018cc51831B9691F0e94b50df50B8; // tmp private key
    address public constant CDP_PAYMASTER = 0xf5d253B62543C6Ef526309D497f619CeF95aD430;
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
