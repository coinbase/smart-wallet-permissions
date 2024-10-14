import {
  Address,
  encodeFunctionData,
  Hex,
  isAddressEqual,
  zeroAddress,
} from "viem";
import { Call, SmartWalletPermission } from "../types";
import { hashPermission } from "./hashPermission";
import { permissionContractAbi } from "../abi/PermissionCallableAllowedContractNativeTokenSpendPermission";

type PrepareUseSpendPermissionArgs = {
  permission: SmartWalletPermission;
  callsSpend: bigint;
  gasSpend: bigint; // equivalent to EntryPoint.getRequiredPrefund
  paymaster: Address;
};

export async function prepareUseSpendPermission({
  permission,
  callsSpend,
  gasSpend,
  paymaster,
}: PrepareUseSpendPermissionArgs): Promise<Call> {
  const totalSpend = isAddressEqual(paymaster, zeroAddress)
    ? callsSpend + gasSpend
    : callsSpend;

  const useSpendPermission = {
    to: permission.permissionContract as Address,
    value: "0x0" as Hex,
    data: encodeFunctionData({
      abi: permissionContractAbi,
      functionName: "useSpendPermission",
      args: [hashPermission(permission), totalSpend],
    }),
  };
  return useSpendPermission;
}
