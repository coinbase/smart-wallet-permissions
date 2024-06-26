import {
  Address,
  Hex,
  decodeAbiParameters,
  encodeAbiParameters,
  keccak256,
  numberToBytes,
  parseAbiParameters,
  toHex,
} from "viem";

/**
 *  wallet_grantPermission utils
 */

type Session = {
  account: Address;
  approval: Hex;
  signer: Hex;
  permissionContract: Address;
  permissionData: Hex;
  expiresAt: number; // unix seconds
  chainId: bigint;
  verifyingContract: Address;
};

const sessionStruct = parseAbiParameters([
  "Session session",
  "struct Session { address account; bytes approval; bytes signer; address permissionContract; bytes permissionData; uint40 expiresAt; uint256 chainId; address verifyingContract; }",
])[0];

const sessionStructApprovalStripped = parseAbiParameters([
  "Session session",
  "struct Session { address account; bytes signer; address permissionContract; bytes permissionData; uint40 expiresAt; uint256 chainId; address verifyingContract; }",
])[0];

const SessionManager = "0xF3B1EDD3e9c0c2512040deA41916aecAb9518a37";
const SessionCallPermission = "0xfef00dbf81c25b5892ba303da275ec82cc39dddd";

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
  return keccak256(
    encodeAbiParameters([sessionStructApprovalStripped], [session as never])
  );
}

// returns a new Session with the approval properly formatting the signature of another owner
export function updateSessionWithApproval({
  session,
  ownerIndex,
  signature,
}: {
  session: Session;
  ownerIndex: string; // index of the passkey owner signing session approval
  signature: Hex;
}): Session {
  return {
    ...session,
    approval: wrapSignature({ ownerIndex, signatureData: signature }),
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
const userOperationStruct = parseAbiParameters([
  "UserOperation userOperation",
  "struct UserOperation { address sender; uint256 nonce; bytes initCode; bytes callData; uint256 callGasLimit; uint256 verificationGasLimit; uint256 preVerificationGas; uint256 maxFeePerGas; uint256 maxPriorityFeePerGas; bytes paymasterAndData; bytes signature; }",
])[0];

// types forked from permissionless to save dependency
type EntryPointVersion = "v0.6" | "v0.7";
type UserOperation<entryPointVersion extends EntryPointVersion> =
  entryPointVersion extends "v0.6"
    ? {
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
        factory?: never;
        factoryData?: never;
        paymaster?: never;
        paymasterVerificationGasLimit?: never;
        paymasterPostOpGasLimit?: never;
        paymasterData?: never;
      }
    : {
        sender: Address;
        nonce: bigint;
        factory?: Address;
        factoryData?: Hex;
        callData: Hex;
        callGasLimit: bigint;
        verificationGasLimit: bigint;
        preVerificationGas: bigint;
        maxFeePerGas: bigint;
        maxPriorityFeePerGas: bigint;
        paymaster?: Address;
        paymasterVerificationGasLimit?: bigint;
        paymasterPostOpGasLimit?: bigint;
        paymasterData?: Hex;
        signature: Hex;
        initCode?: never;
        paymasterAndData?: never;
      };

// abi-decodes `permissionsContext` to recover a session, use when parsing `capabilities.permissions.context` from 5792 wallet_sendCalls
export function decodePermissionsContext(permissionsContext: Hex): Session {
  const [session] = decodeAbiParameters([sessionStruct], permissionsContext);
  return session as Session;
}

// returns a new UserOperation with the signature properly formatted for use with the SessionManager
export function updateUserOpSignature({
  userOp,
  sessionManagerOwnerIndex,
  session,
  sessionKeySignature,
}: {
  userOp: UserOperation<"v0.6">;
  sessionManagerOwnerIndex: string;
  session: Session;
  sessionKeySignature: Hex;
}): UserOperation<"v0.6"> {
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

const signatureWrapperStruct = parseAbiParameters([
  "SignatureWrapper signatureWrapper",
  "struct SignatureWrapper { uint256 ownerIndex; bytes signatureData; }",
])[0];

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
