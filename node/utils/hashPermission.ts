import { Hex, encodeAbiParameters, keccak256 } from "viem";
import { SmartWalletPermission } from "../types";

export const hashablePermissionStruct = {
  name: "hashablePermission",
  type: "tuple",
  internalType: "struct HashablePermission",
  components: [
    { name: "account", type: "address", internalType: "address" },
    { name: "chainId", type: "uint256", internalType: "uint256" },
    { name: "expiry", type: "uint48", internalType: "uint48" },
    { name: "signerHash", type: "bytes32", internalType: "bytes32" },
    { name: "permissionContract", type: "address", internalType: "address" },
    { name: "permissionValuesHash", type: "bytes32", internalType: "bytes32" },
    { name: "verifyingContract", type: "address", internalType: "address" },
  ],
} as const;

export function hashPermission(permission: SmartWalletPermission): Hex {
  const { signer, permissionValues, approval, ...hashablePermission } =
    permission;
  return keccak256(
    encodeAbiParameters(
      [hashablePermissionStruct],
      [
        {
          ...hashablePermission,
          signerHash: keccak256(signer),
          permissionValuesHash: keccak256(permissionValues),
        } as never,
      ],
    ),
  );
}
