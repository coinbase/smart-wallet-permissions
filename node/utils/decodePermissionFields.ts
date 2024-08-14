import { decodeAbiParameters, Hex } from "viem";

export function decodePermissionFields(permissionFields: Hex) {
    const [spendLimit, rollingPeriod, allowedContract] = decodeAbiParameters(
        [
            { name: "spendLimit", type: "uint256" },
            { name: "rollingPeriod", type: "bytes" },
            { name: "allowedContract", type: "address" },
        ],
        permissionFields,
    );

    return {
        spendLimit,
        rollingPeriod,
        allowedContract,
    };
}