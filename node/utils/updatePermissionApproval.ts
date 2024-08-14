import { Hex } from "viem";
import { SmartWalletPermission } from "../types";

// returns a new Permission with the approval properly formatting the signature of another owner
export function updatePermissionApproval({
    permission,
    signature,
}: {
    permission: SmartWalletPermission;
    signature: Hex;
}): SmartWalletPermission {
    return {
        ...permission,
        approval: signature,
    };
}