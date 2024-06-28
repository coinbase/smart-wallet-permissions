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

export type Session = {
  account: Address;
  approval: Hex;
  signer: Hex;
  permissionContract: Address;
  permissionData: Hex;
  expiresAt: number; // unix seconds
  chainId: bigint;
  verifyingContract: Address;
};

export const sessionStruct = parseAbiParameter([
  "Session session",
  "struct Session { address account; bytes approval; bytes signer; address permissionContract; bytes permissionData; uint40 expiresAt; uint256 chainId; address verifyingContract; }",
]);

// Hashable version of Session struct.
// IMPORTANT: for some reason, must rename the struct to not clash with normal "Session". For some reason, it seems like viem caches the struct names in ABIs???
// 1. Removes `bytes approval`
// 2. Pre-hashes `bytes signer` into `bytes32 signerHash`
// 3. Pre-hashes `bytes permissionData` into `bytes32 permissionDataHash`
export const sessionStructHashable = parseAbiParameter([
  "SessionHashable sessionHashable",
  "struct SessionHashable { address account; bytes32 signerHash; address permissionContract; bytes32 permissionDataHash; uint40 expiresAt; uint256 chainId; address verifyingContract; }",
]);

export const SessionManager = "0x5ef2B2260de6A48138d6fc185f1BdE440CA0C9A0";
export const SessionCallPermission =
  "0xD28D11a3781Baf3A6867C266385619F2d6Cbba1E";

// create a session object with defaulted parameters for validating with the SessionCallPermission validation contract
export function createSessionCallPermissionSession({
  account,
  signer,
  expiry,
  nativeTokenLimit = 0n, // 0 ETH
  chainId = 85432n, // base sepolia
}: {
  account: Address;
  signer: Hex;
  expiry: number; // units: seconds
  nativeTokenLimit: bigint; // units: wei
  chainId: bigint;
}): Session {
  return {
    account,
    approval: "0x",
    signer,
    permissionContract: SessionCallPermission,
    permissionData: toHex(numberToBytes(nativeTokenLimit, { size: 32 })),
    expiresAt: expiry,
    chainId,
    verifyingContract: SessionManager,
  };
}

// returns a bytes32 to sign, encodes session struct with approval stripped (later populated by signing over this hash)
export function hashSession(session: Session): Hex {
  const { approval, signer, permissionData, ...sessionHashable } = session;
  return keccak256(
    encodeAbiParameters(
      [sessionStructHashable],
      [
        {
          ...sessionHashable,
          signerHash: keccak256(session.signer),
          permissionDataHash: keccak256(session.permissionData),
        } as never,
      ]
    )
  );
}

// returns a new Session with the approval properly formatting the signature of another owner
export function updateSessionWithApproval({
  session,
  signature,
}: {
  session: Session;
  signature: Hex;
}): Session {
  return {
    ...session,
    approval: signature,
  };
}

// abi-encodes a session, use when returning `permissionsContext` for 7715 wallet_grantPermission
export function encodePermissionsContext(session: Session): Hex {
  return encodeAbiParameters([sessionStruct], [session as never]);
}

/**
 *  wallet_sendCalls utils
 */

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

// abi-decodes `permissionsContext` to recover a session, use when parsing `capabilities.permissions.context` from 5792 wallet_sendCalls
export function decodePermissionsContext(permissionsContext: Hex): Session {
  const [session] = decodeAbiParameters([sessionStruct], permissionsContext);
  return session;
}

// returns a new UserOperation with the signature properly formatted for use with the SessionManager
export function updateUserOpSignature({
  userOp,
  sessionManagerOwnerIndex,
  session,
  sessionKeySignature,
}: {
  userOp: UserOperation;
  sessionManagerOwnerIndex: string;
  session: Session;
  sessionKeySignature: Hex;
}): UserOperation {
  if (session.permissionContract !== SessionCallPermission) {
    throw Error(
      "Only supporting permissionContract=SessionCallPermission for now"
    );
  }
  const authData = encodeAbiParameters(
    [
      sessionStruct,
      { name: "sessionKeySignature", type: "bytes" },
      userOperationStruct,
    ],
    [session, sessionKeySignature, userOp] as never
  );
  const signature = wrapSignature({
    ownerIndex: sessionManagerOwnerIndex,
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
  ownerIndex: string;
  signatureData: Hex;
}): Hex {
  return encodeAbiParameters([signatureWrapperStruct], [
    { ownerIndex, signatureData },
  ] as never);
}
