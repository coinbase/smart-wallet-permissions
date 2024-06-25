import {
  Address,
  Hex,
  decodeAbiParameters,
  encodeAbiParameters,
  keccak256,
  parseAbiItem,
} from "viem";

// forked from permissionless
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

type Session = {
  account: Address;
  approval: Hex;
  signer: Hex;
  permissionContract: Address;
  permissionData: Hex;
  expiresAt: number; // unix seconds
  chainId: number;
  verifyingContract: Address;
};

const sessionStruct = parseAbiItem(`struct Session {
    address account;
    bytes approval;
    bytes signer;
    address permissionContract;
    bytes permissionData;
    uint40 expiresAt;
    uint256 chainId;
    address verifyingContract;
}`);

const sessionStructApprovalStripped = parseAbiItem(`struct Session {
    address account;
    bytes signer;
    address permissionContract;
    bytes permissionData;
    uint40 expiresAt;
    uint256 chainId;
    address verifyingContract;
}`);

const userOperationStruct = parseAbiItem(`struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}`);

const signatureWrapperStruct = parseAbiItem(`struct SignatureWrapper {
    uint256 ownerIndex;
    bytes signatureData;
}`);

const SessionManager = "0xF3B1EDD3e9c0c2512040deA41916aecAb9518a37";
const SessionCallPermission = "0xfef00dbf81c25b5892ba303da275ec82cc39dddd";

// create a session object with defaulted parameters for validating with the SessionCallPermission validation contract
function createSessionCallPermissionSession({
  account,
  signer,
  duration = 3600, // 1 hour
  nativeTokenLimit = 0n, // 0 ETH
  chainId = 85432, // base sepolia
}: {
  account: Address;
  signer: Hex;
  duration: number; // units: seconds
  nativeTokenLimit: bigint; // units: wei
  chainId: number;
}): Session {
  return {
    account,
    approval: "0x",
    signer,
    permissionContract: SessionCallPermission,
    permissionData: encodeAbiParameters(["bytes32"], [
      nativeTokenLimit,
    ] as never),
    expiresAt: Date.now() / 1000 + duration,
    chainId,
    verifyingContract: SessionManager,
  };
}

// returns a bytes32 to sign, encodes session struct with approval stripped (later populated by signing over this hash)
function hashSession(session: Session): Hex {
  return keccak256(
    encodeAbiParameters([sessionStructApprovalStripped], [session as never])
  );
}

// abi-encodes a session, use when returning `permissionsContext` for 7715 wallet_grantPermission
function encodePermissionsContext(session: Session): Hex {
  return encodeAbiParameters([sessionStruct], [session as never]);
}

// abi-decodes `permissionsContext` to recover a session, use when parsing `capabilities.permissions.context` from 5792 wallet_sendCalls
function decodePermissionsContext(permissionsContext: Hex): Session {
  const [session] = decodeAbiParameters([sessionStruct], permissionsContext);
  return session as Session;
}

// returns a new Session with the approval properly formatting the signature of another owner
function updateSessionApproval({
  session,
  ownerIndex,
  signature,
}: {
  session: Session;
  ownerIndex: number;
  signature: Hex;
}): Session {
  return {
    ...session,
    approval: wrapSignature({ ownerIndex, signatureData: signature }),
  };
}

// returns a new UserOperation with the signature properly formatted for use with the SessionManager
function updateUserOpSignature({
  userOp,
  sessionManagerOwnerIndex,
  session,
  sessionKeySignature,
}: {
  userOp: UserOperation<"v0.6">;
  sessionManagerOwnerIndex: number;
  session: Session;
  sessionKeySignature: Hex;
}): UserOperation<"v0.6"> {
  let authData: Hex;
  if (session.permissionContract === "0x") {
    authData = encodeAbiParameters(
      [sessionStruct, "bytes", userOperationStruct],
      [session, sessionKeySignature, userOp] as never
    );
  } else {
    throw Error(
      "Only supporting permissionContract=SessionCallPermission for now"
    );
  }
  const signature = wrapSignature({
    ownerIndex: sessionManagerOwnerIndex,
    signatureData: authData,
  });

  return {
    ...userOp,
    signature,
  };
}

// wraps a signature with an ownerIndex for verification within CoinbaseSmartWallet
function wrapSignature({
  ownerIndex,
  signatureData,
}: {
  ownerIndex: number;
  signatureData: Hex;
}): Hex {
  return encodeAbiParameters([signatureWrapperStruct], [
    { ownerIndex, signatureData },
  ] as never);
}
