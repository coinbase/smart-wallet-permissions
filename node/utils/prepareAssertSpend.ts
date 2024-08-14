import { Address, encodeFunctionData, Hex } from "viem";
import { Call, SmartWalletPermission } from "../types";
import { decodePermissionContext } from "./decodePermissionContext";
import { nativeTokenRollingSpendLimitPermissionAbi } from "../abi/NativeTokenRollingSpendLimitPermission";
import { hashPermission } from "./hashPermission";
import { decodePermissionFields } from "./decodePermissionFields";

type PrepareAssertSpendArgs = {
    permission: SmartWalletPermission,
    callsSpend: bigint,
    gasSpend: bigint, // equivalent to EntryPoint.getRequiredPrefund
    paymaster: Address
}

export async function prepareAssertSpend({
    permission,
    callsSpend,
    gasSpend,
    paymaster,
}: PrepareAssertSpendArgs): Promise<Call> {
    const { spendLimit, rollingPeriod } = decodePermissionFields(permission.permissionFields)
    const assertSpend = {
        target: permission.permissionContract as Address,
        value: "0x0" as Hex,
        data: encodeFunctionData({
            abi: nativeTokenRollingSpendLimitPermissionAbi,
            functionName: "assertSpend",
            args: [
                hashPermission(permission),
                spendLimit,
                rollingPeriod,
                callsSpend,
                gasSpend,
                paymaster
            ],
        }),
    };
    return assertSpend;
}
  