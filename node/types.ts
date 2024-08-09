import { Address, Hex, parseAbiParameter } from "viem";

export type SmartWalletPermission = {
    account: Address;
    chainId: bigint;
    expiry: number; // unix seconds
    signer: Hex; // ethereum address or p256 public key
    permissionContract: Address;
    permissionData: Hex;
    verifyingContract: Address;
    approval: Hex;
};

export type Call = {
    to: Address;
    data: Hex;
    value: Hex;
};

export const permissionStruct = parseAbiParameter([
    "Permission permission",
    "struct Permission { address account; uint256 chainId; uint40 expiry; bytes signer; address permissionContract; bytes permissionData; address verifyingContract; bytes approval; }",
]);