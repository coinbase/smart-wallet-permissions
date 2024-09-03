// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {UniversalSandbox} from "../docs/examples/UniversalSandbox.sol";

/**
 * forge script DeployExamles --account dev --sender $SENDER --rpc-url $BASE_SEPOLIA_RPC --verify --verifier-url
 * $SEPOLIA_BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY --broadcast -vvvv
 */
contract DeployExamples is Script {
    function run() public {
        vm.startBroadcast();

        new UniversalSandbox{salt: 0}();

        vm.stopBroadcast();
    }
}
