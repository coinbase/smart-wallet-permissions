// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {SessionManager} from "../src/SessionManager.sol";
import {SessionCallPermission} from "../src/permissions/SessionCallPermission.sol";

contract Deploy is Script {
    function run() public {
        vm.startBroadcast();

        SessionManager sessionManager = new SessionManager();
        logAddress("SessionManager", address(sessionManager));
        SessionCallPermission sessionCallPermission = new SessionCallPermission();
        logAddress("SessionCallPermission", address(sessionCallPermission));

        vm.stopBroadcast();
    }

    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
