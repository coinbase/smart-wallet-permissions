// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {Test, console2} from "forge-std/Test.sol";

import {PermissionManager} from "../../src/PermissionManager.sol";

import {MockPermissionContract} from "../mocks/MockPermissionContract.sol";
import {Base} from "./Base.sol";

contract PermissionManagerBase is Test, Base {
    PermissionManager permissionManager;
    uint256 cosignerPk = uint256(keccak256("cosigner"));
    address cosigner = vm.addr(cosignerPk);
    MockPermissionContract successPermissionContract;
    MockPermissionContract failPermissionContract;

    function _initializePermissionManager() internal {
        _initialize();

        permissionManager = new PermissionManager(owner, cosigner);
        successPermissionContract = new MockPermissionContract(false);
        failPermissionContract = new MockPermissionContract(true);
    }

    function _createPermission() internal view returns (PermissionManager.Permission memory) {
        return PermissionManager.Permission({
            account: address(account),
            expiry: type(uint48).max,
            signer: abi.encode(permissionSigner),
            permissionContract: address(successPermissionContract),
            permissionValues: hex"",
            approval: hex""
        });
    }

    function _createBeforeCallsData(PermissionManager.Permission memory permission)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(PermissionManager.beforeCalls.selector, permission);
    }

    function _signPermission(PermissionManager.Permission memory permission) internal view returns (bytes memory) {
        bytes32 permissionHash = permissionManager.hashPermission(permission);
        bytes32 replaySafeHash = account.replaySafeHash(permissionHash);
        bytes memory signature = _sign(ownerPk, replaySafeHash);
        bytes memory wrappedSignature = _applySignatureWrapper({ownerIndex: 0, signatureData: signature});
        return wrappedSignature;
    }
}
