import { Address, encodeFunctionData, Hex } from "viem";
import { UserOperation } from "permissionless";

import { PermissionManager } from "../constants";
import { SmartWalletPermission } from "../types";
import { permissionManagerAbi } from "../abi/PermissionManager";

type PrepareCheckBeforeCallsArgs = {
    permission: SmartWalletPermission
    paymaster: Address
    userOpHash: Hex
    userOpCosignature: Hex
}

export function prepareCheckBeforeCalls({
    permission,
    paymaster,
    userOpHash,
    userOpCosignature
}: PrepareCheckBeforeCallsArgs) {
    const checkBeforeCalls = {
        target: PermissionManager,
        value: "0x0" as Hex,
        data: encodeFunctionData({
            abi: permissionManagerAbi,
            functionName: "checkBeforeCalls",
            args: [
                permission.expiry,
                permission.permissionContract,
                paymaster,
                userOpHash,
                userOpCosignature
            ],
        }),
    };
    return checkBeforeCalls;
}