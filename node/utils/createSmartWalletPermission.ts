import { Address, encodeAbiParameters, Hex } from "viem";
import {
  DataType,
  PermissionType,
  permissionValuesStruct,
  SignerType,
  SmartWalletPermission,
} from "../types";
import {
  PermissionManager,
  PermissionCallableAllowedContractNativeTokenRecurringAllowance,
} from "../constants";

// convert between received PermissionRequest to contract-compatible SmartWalletPermission
export function createSmartWalletPermission({
  chainId,
  address,
  expiry,
  signer,
  permission,
  policies,
}: {
  chainId: Hex;
  address: Address;
  expiry: number; // unix seconds
  signer: DataType;
  permission: DataType;
  policies: { type: string; data: Record<string, any> }[];
}): SmartWalletPermission {
  if (signer.type !== SignerType.P256) {
    throw Error("Invalid signer type");
  }
  if (permission.type !== PermissionType.NativeTokenRecurringAllowance) {
    throw Error("Invalid permission type");
  }

  const permissionValues = encodeAbiParameters(
    [permissionValuesStruct],
    [
      {
        recurringAllowance: {
          start: permission.data.start,
          period: permission.data.period,
          allowance: permission.data.allowance,
        },
        allowedContract: permission.data.allowedContract,
      },
    ],
  );

  return {
    account: address,
    chainId: BigInt(chainId),
    expiry,
    signer: signer.data.publicKey,
    permissionContract:
      PermissionCallableAllowedContractNativeTokenRecurringAllowance,
    permissionValues,
    verifyingContract: PermissionManager,
    approval: "0x",
  };
}
