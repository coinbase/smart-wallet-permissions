// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {PermissionManager} from "../src/PermissionManager.sol";
import {CallWithPermission} from "../src/permissions/CallWithPermission/CallWithPermission.sol";
import {Click} from "../src/permissions/CallWithPermission/examples/Click.sol";

// forge script Deploy --account dev --rpc-url $BASE_SEPOLIA_RPC --verify --verifier-url $SEPOLIA_BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY --broadcast -vvvv
contract Deploy is Script {
    function run() public {
        vm.startBroadcast();

        // PermissionManager sessionManager = new PermissionManager();
        // logAddress("PermissionManager", address(sessionManager));
        // CallWithPermission sessionCallPermission = new CallWithPermission();
        // logAddress("CallWithPermission", address(sessionCallPermission));
        Click click = new Click();

        vm.stopBroadcast();
    }

    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
