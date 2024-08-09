import { decodeAbiParameters, Hex } from "viem";
import { permissionStruct, SmartWalletPermission } from "../types";

export function decodePermissionContext(permissionContext: Hex): {
    permissionManagerOwnerIndex: bigint;
    permission: SmartWalletPermission;
  } {
    const [permissionManagerOwnerIndex, permission] = decodeAbiParameters(
      [
        { name: "permissionManagerOwnerIndex", type: "uint256" },
        permissionStruct,
      ],
      permissionContext,
    );
    return { permissionManagerOwnerIndex, permission };
  }
  