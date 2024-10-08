// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {PermissionManager} from "../src/PermissionManager.sol";
import {SpendPermissions} from "../src/SpendPermissions.sol";
import {PermissionCallableAllowedContractNativeTokenRecurringAllowance as PermissionContract} from
    "../src/permissions/PermissionCallableAllowedContractNativeTokenRecurringAllowance.sol";

/**
 * forge script Deploy --account dev --sender $SENDER --rpc-url $BASE_SEPOLIA_RPC --verify --verifier-url
 * $SEPOLIA_BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY --broadcast -vvvv
 */
contract Deploy is Script {
    /// @dev Deployment address consistent across chains
    ///      https://github.com/coinbase/magic-spend/releases/tag/v1.0.0
    address public constant MAGIC_SPEND = 0x011A61C07DbF256A68256B1cB51A5e246730aB92;
    address public constant OWNER = 0x6EcB18183838265968039955F1E8829480Db5329; // dev wallet
    address public constant COSIGNER = 0xAda9897F517018cc51831B9691F0e94b50df50B8; // tmp private key
    address public constant CDP_PAYMASTER = 0xC484bCD10aB8AD132843872DEb1a0AdC1473189c; // limiting paymaster
    address public constant CDP_PAYMASTER_PUBLIC = 0xf5d253B62543C6Ef526309D497f619CeF95aD430; // public

    PermissionManager permissionManager;
    PermissionContract permissionContract;

    function run() public {
        vm.startBroadcast();

        deploy();

        vm.stopBroadcast();
    }

    function deploy() internal {}

    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
