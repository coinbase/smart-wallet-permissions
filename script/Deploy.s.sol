// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {PermissionManager} from "../src/PermissionManager.sol";
import {Click} from "../src/examples/Click.sol";
import {NativeTokenRollingSpendLimitPermission} from
    "../src/permissions/NativeTokenRollingSpendLimit/NativeTokenRollingSpendLimitPermission.sol";

// forge script Deploy --account dev --rpc-url $BASE_SEPOLIA_RPC --verify --verifier-url $SEPOLIA_BASESCAN_API
// --etherscan-api-key $BASESCAN_API_KEY --broadcast -vvvv
contract Deploy is Script {
    function run() public {
        vm.startBroadcast();

        // PermissionManager sessionManager = new PermissionManager();
        // logAddress("PermissionManager", address(sessionManager));
        // AllowedContractPermission sessionCallPermission = new AllowedContractPermission();
        // logAddress("AllowedContractPermission", address(sessionCallPermission));
        // Click click = new Click();
        // logAddress("Click", address(click));

        vm.stopBroadcast();
    }

    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
