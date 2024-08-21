import { Address, encodeFunctionData, Hex } from "viem";

import { PermissionManager } from "../constants";
import { SmartWalletPermission } from "../types";
import { permissionManagerAbi } from "../abi/PermissionManager";

type PrepareBeforeCallsArgs = {
  permission: SmartWalletPermission;
  paymaster: Address;
  cosigner: Address;
};

export function prepareBeforeCalls({
  permission,
  paymaster,
  cosigner,
}: PrepareBeforeCallsArgs) {
  const checkBeforeCalls = {
    to: PermissionManager,
    value: "0x0" as Hex,
    data: encodeFunctionData({
      abi: permissionManagerAbi,
      functionName: "beforeCalls",
      args: [permission, paymaster, cosigner],
    }),
  };
  return checkBeforeCalls;
}
