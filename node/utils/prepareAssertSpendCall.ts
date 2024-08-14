import { Address, encodeFunctionData, Hex } from "viem";
import { Call } from "../types";
import { decodePermissionContext } from "./decodePermissionContext";
import { nativeTokenRollingSpendLimitPermissionAbi } from "../abi/NativeTokenRollingSpendLimitPermission";
import { hashPermission } from "./hashPermission";

type AssertSpendArgs = {
    permisisonsContext: Hex,
    spendLimit: bigint,
    rollingPeriod: number,
    callsSpend: bigint,
    gasSpend: bigint,
    paymaster: Address
}

export async function prepareAssertSpendCall({
    permisisonsContext,
    spendLimit,
    rollingPeriod,
    callsSpend,
    gasSpend,
    paymaster,
}: AssertSpendArgs): Promise<Call> {
    const { permission } = decodePermissionContext(permisisonsContext);
    const assertSpendCall = {
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
    return assertSpendCall;
}
  