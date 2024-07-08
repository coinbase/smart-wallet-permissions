import {
  Address,
  Hex,
  decodeAbiParameters,
  encodeAbiParameters,
  keccak256,
  numberToBytes,
  parseAbiParameter,
  toHex,
} from "viem";

/**
 *  wallet_grantPermission utils
 */

export type Permission = {
  account: Address;
  chainId: bigint;
  expiry: number; // unix seconds
  signer: Hex; // ethereum address or passkey public key
  permissionContract: Address;
  permissionData: Hex;
  verifyingContract: Address;
  approval: Hex;
};

export const permissionStruct = parseAbiParameter([
  "Permission permission",
  "struct Permission { address account; uint256 chainId; uint40 expiry; bytes signer; address permissionContract; bytes permissionData; address verifyingContract; bytes approval; }",
]);

// Hashable version of Permission struct.
// IMPORTANT: for some reason, must rename the struct to not clash with normal "Permission". For some reason, it seems like viem caches the struct names in ABIs???
// 1. Pre-hash `bytes signer` into `bytes32 signerHash`
// 2. Pre-hash `bytes permissionData` into `bytes32 permissionDataHash`
// 3. Remove `bytes approval`
export const hashablePermissionStruct = parseAbiParameter([
  "HashablePermission hashablePermission",
  "struct HashablePermission { address account; uint256 chainId; uint40 expiry; bytes32 signerHash; address permissionContract; bytes32 permissionDataHash; address verifyingContract; }",
]);

// export const PermissionManager = "0xd929f9b996298a235b2d49101ebcab6851732a5b"; // expiry check, not working without bundler approval
export const PermissionManager = "0x55b6d23b07357dc3b60f1a44c8a591f6067ce48f"; // no expiry check, use while waiting for bundler approval
export const CallWithPermission = "0x245e88921605b20338456529956a30b795636a55";
export const TestPermission = "0xa54d48a5ed676baa9a85aba1482b3ee9b4a97ee3";

// create a session object with defaulted parameters for validating with the PermissionCallPermission validation contract
export function createPermissionCallWithPermission({
  account,
  chainId = 85432n, // base sepolia
  expiry,
  signer,
  nativeTokenLimit = 0n, // 0 ETH
}: {
  account: Address;
  chainId: bigint;
  expiry: number; // unix seconds
  signer: Hex;
  nativeTokenLimit: bigint; // wei
}): Permission {
  return {
    account,
    chainId,
    expiry,
    signer,
    permissionContract: CallWithPermission,
    permissionData: toHex(numberToBytes(nativeTokenLimit, { size: 32 })),
    verifyingContract: PermissionManager,
    approval: "0x",
  };
}

// returns a bytes32 to sign, encodes Permission struct with approval stripped (later populated by signing over this hash)
export function hashPermission(permission: Permission): Hex {
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
      ]
    )
  );
}

// returns a new Permission with the approval properly formatting the signature of another owner
export function updatePermissionWithApproval({
  permission,
  signature,
}: {
  permission: Permission;
  signature: Hex;
}): Permission {
  return {
    ...permission,
    approval: signature,
  };
}

// abi-encodes a permission, use when returning `permissionContext` for 7715 wallet_grantPermission
export function encodePermissionContext(
  permissionManagerOwnerIndex: bigint,
  permission: Permission
): Hex {
  return encodeAbiParameters(
    [
      { name: "permissionManagerOwnerIndex", type: "uint256" },
      permissionStruct,
    ],
    [permissionManagerOwnerIndex, permission as never]
  );
}

/**
 *  wallet_sendCalls utils
 */

// abi-decodes `permissionContext` to recover a permission and ownerindex, use when parsing `capabilities.permissions.context` from 5792 wallet_sendCalls
export function decodePermissionContext(permissionContext: Hex): {
  permissionManagerOwnerIndex: bigint;
  permission: Permission;
} {
  const [permissionManagerOwnerIndex, permission] = decodeAbiParameters(
    [
      { name: "permissionManagerOwnerIndex", type: "uint256" },
      permissionStruct,
    ],
    permissionContext
  );
  return { permissionManagerOwnerIndex, permission };
}

// note this is for v0.6, our current Entrypoint version for CoinbaseSmartWallet
export const userOperationStruct = parseAbiParameter([
  "UserOperation userOperation",
  "struct UserOperation { address sender; uint256 nonce; bytes initCode; bytes callData; uint256 callGasLimit; uint256 verificationGasLimit; uint256 preVerificationGas; uint256 maxFeePerGas; uint256 maxPriorityFeePerGas; bytes paymasterAndData; bytes signature; }",
]);

// types forked from permissionless to save dependency
type UserOperation = {
  sender: Address;
  nonce: bigint;
  initCode: Hex;
  callData: Hex;
  callGasLimit: bigint;
  verificationGasLimit: bigint;
  preVerificationGas: bigint;
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
  paymasterAndData: Hex;
  signature: Hex;
};

// returns a new UserOperation with the signature properly formatted for use with the PermissionManager
export function updateUserOpSignature({
  userOp,
  permissionManagerOwnerIndex,
  permission,
  permissionSignerSignature,
}: {
  userOp: UserOperation;
  permissionManagerOwnerIndex: bigint;
  permission: Permission;
  permissionSignerSignature: Hex;
}): UserOperation {
  const authData = encodeAbiParameters(
    [
      permissionStruct,
      { name: "permissionSignerSignature", type: "bytes" },
      userOperationStruct,
    ],
    [permission, permissionSignerSignature, userOp] as never
  );
  const signature = wrapSignature({
    ownerIndex: permissionManagerOwnerIndex,
    signatureData: authData,
  });

  return {
    ...userOp,
    signature,
  };
}

/**
 *  shared, internal utils
 */

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
