// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

import {PermissionManager} from "../src/PermissionManager.sol";
import {NativeTokenRollingSpendLimitPermission} from
    "../src/permissions/NativeTokenRollingSpendLimit/NativeTokenRollingSpendLimitPermission.sol";
import {Click} from "../src/examples/Click.sol";

// forge script Debug --broadcast -vvvv
contract Debug is Script {
    /// @dev Deployment address consistent across chains
    ///      https://github.com/coinbase/magic-spend/releases/tag/v1.0.0
    address public constant MAGIC_SPEND = 0x011A61C07DbF256A68256B1cB51A5e246730aB92;
    address public constant OWNER = 0x6EcB18183838265968039955F1E8829480Db5329; // dev wallet
    address public constant COSIGNER = 0xAda9897F517018cc51831B9691F0e94b50df50B8; // tmp private key
    address public constant CDP_PAYMASTER = 0xf5d253B62543C6Ef526309D497f619CeF95aD430;

    // recent deploys
    address public constant MANAGER = 0x384E8b4617886C7070ABd6037c4D5AbeC5B1d14d;

    PermissionManager permissionManager;
    NativeTokenRollingSpendLimitPermission nativeTokenRollingSpendLimitPermission;

    function run() public {
        vm.startBroadcast();

        // debugCosignature(userOpHash, userOpCosignature);
        debugCheckBeforeCalls();

        vm.stopBroadcast();
    }

    function debugCosignature() public {
        bytes32 userOpHash = 0x41c969e7044df9a75d8b66d33641885b5eab3a03bb1cda2a6f1be720a40aaf44;
        bytes memory userOpCosignature = hex"d72c4bebbf8f8df9e05b5a8454c9a2c80f1391b6ba6f8692828e7b93baeedda87e5ec5229ace02083b44827764ace31fe6b393dcb84da0e257ca58f528683aa81b";
        address userOpCosigner = ECDSA.recover(userOpHash, userOpCosignature);
        logAddress("userOpCosigner", userOpCosigner);
    }

    function debugCheckBeforeCalls() public {
        console2.logBytes4(PermissionManager.checkBeforeCalls.selector);

        bytes memory paymasterAndData = hex"f5d253b62543c6ef526309d497f619cef95ad4300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021fed48ac2839c982021c62247eb69ed9f03162c2712413b69a83fd031381d4f529e0d042b9cf0467dfa22b41c3dfd8354d412d63473ca1f962662d58c6520641c";
        address paymaster = address(bytes20(paymasterAndData));
        logAddress("paymaster", paymaster);

        bytes memory checkBeforeCallsData = abi.encodeWithSelector(
            PermissionManager.checkBeforeCalls.selector,
            17218875770,
            0x77514b0AA9e8C6F1892F8D107894155C40315edd,
            paymaster,
            0xAda9897F517018cc51831B9691F0e94b50df50B8
        );
        console2.logBytes32(keccak256(checkBeforeCallsData));
    }

    function deploy() internal returns (PermissionManager, NativeTokenRollingSpendLimitPermission) {
        permissionManager = new PermissionManager{salt: 0}(OWNER, COSIGNER);
        logAddress("PermissionManager", address(permissionManager));
        
        nativeTokenRollingSpendLimitPermission = new NativeTokenRollingSpendLimitPermission{salt: 0}(address(permissionManager));
        logAddress("NativeTokenRollingSpendLimitPermission", address(nativeTokenRollingSpendLimitPermission));
    }

    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
