import { Address, Hex } from "viem";

// 1:1 object with contract struct Permission
export type SmartWalletPermission = {
  account: Address;
  chainId: bigint;
  expiry: number; // unix seconds
  signer: Hex; // ethereum address or p256 public key
  permissionContract: Address;
  permissionValues: Hex;
  verifyingContract: Address;
  approval: Hex;
};

export type Call = {
  to: Address;
  value: Hex;
  data: Hex;
};

export type SpendPermission = {
  start: number; // unix seconds
  period: number; // seconds
  allowance: bigint;
};

export type PermissionValues = {
  recurringAllowance: SpendPermission;
  allowedContract: Address;
};

export const permissionStruct = {
  name: "permission",
  type: "tuple",
  internalType: "struct Permission",
  components: [
    { name: "account", type: "address", internalType: "address" },
    { name: "chainId", type: "uint256", internalType: "uint256" },
    { name: "expiry", type: "uint48", internalType: "uint48" },
    { name: "signer", type: "bytes", internalType: "bytes" },
    { name: "permissionContract", type: "address", internalType: "address" },
    { name: "permissionValues", type: "bytes", internalType: "bytes" },
    { name: "verifyingContract", type: "address", internalType: "address" },
    { name: "approval", type: "bytes", internalType: "bytes" },
  ],
} as const;

export const recurringAllowanceStruct = {
  name: "recurringAllowance",
  type: "tuple",
  internalType: "struct SpendPermission",
  components: [
    { name: "start", type: "uint48", internalType: "uint48" },
    { name: "period", type: "uint48", internalType: "uint48" },
    { name: "allowance", type: "uint160", internalType: "uint160" },
  ],
} as const;

export const permissionValuesStruct = {
  name: "permissionValues",
  type: "tuple",
  internalType: "struct PermissionValues",
  components: [
    recurringAllowanceStruct,
    { name: "allowedContract", type: "address", internalType: "address" },
  ],
} as const;

// note this is for v0.6, our current Entrypoint version for CoinbaseSmartWallet
export const userOperationStruct = {
  name: "userOp",
  type: "tuple",
  internalType: "struct UserOperatin",
  components: [
    { name: "sender", type: "address", internalType: "address" },
    { name: "nonce", type: "uint256", internalType: "uint256" },
    { name: "initCode", type: "bytes", internalType: "bytes" },
    { name: "callData", type: "bytes", internalType: "bytes" },
    { name: "callGasLimit", type: "uint256", internalType: "uint256" },
    { name: "verificationGasLimit", type: "uint256", internalType: "uint256" },
    { name: "preVerificationGas", type: "uint256", internalType: "uint256" },
    { name: "maxFeePerGas", type: "uint256", internalType: "uint256" },
    { name: "maxPriorityFeePerGas", type: "uint256", internalType: "uint256" },
    { name: "paymasterAndData", type: "bytes", internalType: "bytes" },
    { name: "signature", type: "bytes", internalType: "bytes" },
  ],
} as const;

export const authDataStruct = {
  name: "authData",
  type: "tuple",
  internalType: "struct AuthData",
  components: [
    userOperationStruct,
    { name: "userOpSignature", type: "bytes", internalType: "bytes" },
    { name: "userOpCosignature", type: "bytes", internalType: "bytes" },
    permissionStruct,
  ],
} as const;

export type DataType = {
  type: string;
  data: Record<string, any>;
};

// signer types

export enum SignerType {
  P256 = "p256",
  Account = "account",
}

export type P256SignerType = {
  type: SignerType.P256;
  data: {
    publicKey: `0x${string}`; // supports both passkeys and cryptokeys
  };
};

export type AccountSignerType = {
  type: SignerType.Account;
  data: {
    address: `0x${string}`; // supports both EOAs and smart contracts
  };
};

// permission types

export enum PermissionType {
  NativeTokenRecurringAllowance = "native-token-recurring-allowance",
}

export type NativeTokenRecurringAllowancePermissionType = {
  type: PermissionType.NativeTokenRecurringAllowance;
  data: {
    start: number; // unix seconds
    period: number; // seconds
    allowedContract: Address;
  };
};
