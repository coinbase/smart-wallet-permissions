
  import { Hex, encodeAbiParameters, parseAbiParameter } from "viem";
  import { UserOperation } from "permissionless";
import { permissionStruct, SmartWalletPermission } from "../types";
  
  // note this is for v0.6, our current Entrypoint version for CoinbaseSmartWallet
  const userOperationStruct = parseAbiParameter([
    "UserOperation userOperation",
    "struct UserOperation { address sender; uint256 nonce; bytes initCode; bytes callData; uint256 callGasLimit; uint256 verificationGasLimit; uint256 preVerificationGas; uint256 maxFeePerGas; uint256 maxPriorityFeePerGas; bytes paymasterAndData; bytes signature; }",
  ]);
  
  // returns a new UserOperation with the signature properly formatted for use with the PermissionManager
  export function formatUserOpSignature({
    userOp,
    permissionSignerSignature,
    cosignature,
    permissionManagerOwnerIndex,
    permission,
  }: {
    userOp: UserOperation<"v0.6">;
    permissionSignerSignature: Hex;
    cosignature: Hex;
    permissionManagerOwnerIndex: bigint;
    permission: SmartWalletPermission;
  }): Hex {
    const authData = encodeAbiParameters(
        [
            userOperationStruct,
            { name: "signature", type: "bytes" }, // permission signer
            { name: "cosignature", type: "bytes" }, // coinbase cosigner
            permissionStruct,
        ],
        [userOp, permissionSignerSignature, cosignature, permission] as never,
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
  