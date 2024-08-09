import { Address, encodeAbiParameters, Hex } from "viem";
import { SmartWalletPermission } from "../types";
import { PermissionManager, NativeTokenRollingSpendLimitPermission } from "../constants";

export function createSmartWalletPermission({
    account,
    chainId,
    expiry,
    signer,
    permission,
    policies
  }: {
    account: Address;
    chainId: bigint;
    expiry: number; // unix seconds
    signer: { type: "p256", data: {publicKey: Hex} };
    permission: { type: "native-token-rolling-spend-limit", data: {
        spendLimit: bigint; // wei
        spendPeriod: number; // unix seconds
        allowedContract: Address
    }}
    policies: { type: string, data: Record<string, any> }[]
  }): SmartWalletPermission {
    const permissionData = encodeAbiParameters(
        [
          { name: 'spendLimit', type: 'uint256' },
          { name: 'spendPeriod', type: 'uint256' },
          { name: 'allowedContract', type: 'address' },
        ],
        [permission.data.spendLimit, BigInt(permission.data.spendPeriod), permission.data.allowedContract],
      );

    return {
      account,
      chainId,
      expiry,
      signer: signer.data.publicKey,
      permissionContract: NativeTokenRollingSpendLimitPermission,
      permissionData,
      verifyingContract: PermissionManager,
      approval: "0x",
    };
  }