import {
    Address,
    encodeFunctionData,
    Hex,
    isAddressEqual,
    zeroAddress,
  } from "viem";
  import { Call, SmartWalletPermission } from "../types";
  import { hashPermission } from "./hashPermission";
import { permissionContractAbi } from "../abi/PermissionCallableAllowedContractNativeTokenRecurringAllowance";
  
  type PrepareUseRecurringAllowanceArgs = {
    permission: SmartWalletPermission;
    callsSpend: bigint;
    gasSpend: bigint; // equivalent to EntryPoint.getRequiredPrefund
    paymaster: Address;
  };
  
  export async function prepareUseRecurringAllowance({
    permission,
    callsSpend,
    gasSpend,
    paymaster,
  }: PrepareUseRecurringAllowanceArgs): Promise<Call> {
    const totalSpend = isAddressEqual(paymaster, zeroAddress)
      ? callsSpend + gasSpend
      : callsSpend;
  
    const useRecurringAllowance = {
      to: permission.permissionContract as Address,
      value: "0x0" as Hex,
      data: encodeFunctionData({
        abi: permissionContractAbi,
        functionName: "useRecurringAllowance",
        args: [hashPermission(permission), totalSpend],
      }),
    };
    return useRecurringAllowance;
  }
  