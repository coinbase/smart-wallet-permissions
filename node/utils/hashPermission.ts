import { Hex, encodeAbiParameters, keccak256, parseAbiParameter } from "viem";
import { SmartWalletPermission } from "../types";

const hashablePermissionStruct = parseAbiParameter([
  "HashablePermission hashablePermission",
  "struct HashablePermission { address account; uint256 chainId; uint40 expiry; bytes32 signerHash; address permissionContract; bytes32 permissionDataHash; address verifyingContract; }",
]);

export function hashPermission(permission: SmartWalletPermission): Hex {
  const { signer, permissionData, approval, ...hashablePermission } =
    permission;
  return keccak256(
    encodeAbiParameters(
      [hashablePermissionStruct],
      [
        {
          ...hashablePermission,
          signerHash: keccak256(signer),
          permissionDataHash: keccak256(permissionData),
        } as never,
      ],
    ),
  );
}
