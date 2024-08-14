import { Address, Hex, parseAbiParameter } from "viem";

// 1:1 object with contract struct Permission
export type SmartWalletPermission = {
    account: Address;
    chainId: bigint;
    expiry: number; // unix seconds
    signer: Hex; // ethereum address or p256 public key
    permissionContract: Address;
    permissionFields: Hex;
    verifyingContract: Address;
    approval: Hex;
};

export type Call = {
    target: Address;
    data: Hex;
    value: Hex;
};

export const permissionStruct = parseAbiParameter([
    "Permission permission",
    "struct Permission { address account; uint256 chainId; uint40 expiry; bytes signer; address permissionContract; bytes permissionFields; address verifyingContract; bytes approval; }",
]);

export type DataType = {
    type: string,
    data: Record<string, any>
}

// signer types

export enum SignerType {
    Provider = "provider",
    P256 = "p256"
}

export type ProviderSignerType = {
    type: SignerType.Provider;
    data: {};
};

export type P256SignerType = {
    type: SignerType.P256;
    data: {
        publicKey: `0x${string}`; // supports both passkeys and cryptokeys
    };
};

// permission types

export enum PermissionType {
    NativeTokenRollingSpendLimit = "native-token-rolling-spend-limit",
}

export type NativeTokenRollingSpendLimitPermissionType = {
    type: PermissionType.NativeTokenRollingSpendLimit, 
    data: {
        spendLimit: Hex; // wei
        rollingPeriod: number; // unix seconds
        allowedContract: Address
    }
}