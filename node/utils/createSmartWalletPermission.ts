import { Address, encodeAbiParameters, Hex } from "viem";
import { DataType, NativeTokenRollingSpendLimitPermissionType, P256SignerType, PermissionType, SignerType, SmartWalletPermission } from "../types";
import { PermissionManager, NativeTokenRollingSpendLimitPermission } from "../constants";

// convert between received PermissionRequest to contract-compatible SmartWalletPermission
export function createSmartWalletPermission({
    chainId, 
    address,
    expiry,
    signer,
    permission,
    policies
}: {
    chainId: Hex;
    address: Address;
    expiry: number; // unix seconds
    signer: DataType
    permission: DataType;
    policies: { type: string, data: Record<string, any> }[];
}): SmartWalletPermission {
    if (signer.type !== SignerType.P256) {
        throw Error("Invalid signer type")
    }
    if (permission.type !== PermissionType.NativeTokenRollingSpendLimit) {
        throw Error("Invalid permission type")
    }

    const permissionFields = encodeAbiParameters(
        [
            { name: 'spendLimit', type: 'uint256' },
            { name: 'rollingPeriod', type: 'uint256' },
            { name: 'allowedContract', type: 'address' },
        ],
        [BigInt(permission.data.spendLimit), BigInt(permission.data.rollingPeriod), permission.data.allowedContract],
    );

    return {
      account: address,
      chainId: BigInt(chainId),
      expiry,
      signer: signer.data.publicKey,
      permissionContract: NativeTokenRollingSpendLimitPermission,
      permissionFields,
      verifyingContract: PermissionManager,
      approval: "0x",
    };
  }