import { encodeAbiParameters, Hex } from "viem";
import { permissionStruct, SmartWalletPermission } from "../types";

export function encodePermissionContext(
    permissionManagerOwnerIndex: bigint,
    permission: SmartWalletPermission
  ): Hex {
    return encodeAbiParameters(
      [
        { name: "permissionManagerOwnerIndex", type: "uint256" },
        permissionStruct,
      ],
      [permissionManagerOwnerIndex, permission]
    );
  }