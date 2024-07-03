// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {PermissionManager} from "../src/PermissionManager.sol";
import {PermissionCallPermission} from "../src/permissions/PermissionCallPermission.sol";
import {TestPermission} from "../src/permissions/TestPermission.sol";

// forge script script/Deploy.s.sol:Deploy --sender $SENDER --keystore $KS --password $PW --rpc-url $BASE_SEPOLIA_RPC --verify --verifier-url $SEPOLIA_BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY --broadcast -vvvv
contract Deploy is Script {
    function run() public {
        vm.startBroadcast();

        PermissionManager sessionManager = new PermissionManager();
        logAddress("PermissionManager", address(sessionManager));
        // PermissionCallPermission sessionCallPermission = new PermissionCallPermission();
        // logAddress("PermissionCallPermission", address(sessionCallPermission));
        // TestPermission testPermission = new TestPermission();
        // logAddress("TestPermission", address(testPermission));

        vm.stopBroadcast();
    }

    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
