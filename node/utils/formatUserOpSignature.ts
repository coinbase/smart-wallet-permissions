
import { Hex, encodeAbiParameters, parseAbiParameter } from "viem";
import { UserOperation } from "permissionless";
import { permissionStruct, SmartWalletPermission } from "../types";
  
  // note this is for v0.6, our current Entrypoint version for CoinbaseSmartWallet
  const userOperationStruct = parseAbiParameter([
    "UserOperation userOperation",
    "struct UserOperation { address sender; uint256 nonce; bytes initCode; bytes callData; uint256 callGasLimit; uint256 verificationGasLimit; uint256 preVerificationGas; uint256 maxFeePerGas; uint256 maxPriorityFeePerGas; bytes paymasterAndData; bytes signature; }",
  ]);

  type FormatSignatureArgs = {
    userOp: UserOperation<"v0.6">;
    userOpSignature: Hex;
    userOpCosignature: Hex;
    permission: SmartWalletPermission;
    permissionManagerOwnerIndex: bigint;
  }
  
  // returns a new UserOperation with the signature properly formatted for use with the PermissionManager
  export function formatUserOpSignature({
    userOp,
    userOpSignature,
    userOpCosignature,
    permission,
    permissionManagerOwnerIndex,
  }: FormatSignatureArgs): Hex {
    const authData = encodeAbiParameters(
        [
            userOperationStruct,
            { name: "userOpSignature", type: "bytes" }, // permission signer
            { name: "userOpCosignature", type: "bytes" }, // coinbase cosigner
            permissionStruct,
        ],
        [userOp, userOpSignature, userOpCosignature, permission] as never,
    );
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
  