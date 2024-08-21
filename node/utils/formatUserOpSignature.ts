import { Hex, encodeAbiParameters, parseAbiParameter } from "viem";
import { UserOperation } from "permissionless";
import { authDataStruct, SmartWalletPermission } from "../types";

type FormatSignatureArgs = {
  userOp: UserOperation<"v0.6">;
  userOpSignature: Hex;
  userOpCosignature: Hex;
  permission: SmartWalletPermission;
  permissionManagerOwnerIndex: bigint;
};

// returns a new UserOperation with the signature properly formatted for use with the PermissionManager
export function formatUserOpSignature({
  userOp,
  userOpSignature,
  userOpCosignature,
  permission,
  permissionManagerOwnerIndex,
}: FormatSignatureArgs): Hex {
  const authData = encodeAbiParameters([authDataStruct], [
    { userOp, userOpSignature, userOpCosignature, permission },
  ])
  const signature = wrapSignature({
    ownerIndex: permissionManagerOwnerIndex,
    signatureData: authData,
  });

  return signature;
}

const signatureWrapperStruct = parseAbiParameter([
  "SignatureWrapper signatureWrapper",
  "struct SignatureWrapper { uint256 ownerIndex; bytes signatureData; }",
]);

// wraps a signature with an ownerIndex for verification within CoinbaseSmartWallet
function wrapSignature({
  ownerIndex,
  signatureData,
}: {
  ownerIndex: bigint;
  signatureData: Hex;
}): Hex {
  return encodeAbiParameters([signatureWrapperStruct], [
    { ownerIndex, signatureData },
  ] as never);
}
