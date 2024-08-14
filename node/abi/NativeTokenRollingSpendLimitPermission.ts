export const nativeTokenRollingSpendLimitPermissionAbi = [
  {
    type: "constructor",
    inputs: [{ name: "manager", type: "address", internalType: "address" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "assertSpend",
    inputs: [
      { name: "permissionHash", type: "bytes32", internalType: "bytes32" },
      { name: "spendLimit", type: "uint256", internalType: "uint256" },
      { name: "rollingPeriod", type: "uint256", internalType: "uint256" },
      { name: "callsSpend", type: "uint256", internalType: "uint256" },
      { name: "gasSpend", type: "uint256", internalType: "uint256" },
      { name: "paymaster", type: "address", internalType: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "calculateRollingSpend",
    inputs: [
      { name: "account", type: "address", internalType: "address" },
      { name: "permissionHash", type: "bytes32", internalType: "bytes32" },
      { name: "rollingPeriod", type: "uint256", internalType: "uint256" },
    ],
    outputs: [
      { name: "rollingSpend", type: "uint256", internalType: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "permissionManager",
    inputs: [],
    outputs: [
      { name: "", type: "address", internalType: "contract PermissionManager" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "validatePermission",
    inputs: [
      { name: "permissionHash", type: "bytes32", internalType: "bytes32" },
      { name: "permissionFields", type: "bytes", internalType: "bytes" },
      {
        name: "userOp",
        type: "tuple",
        internalType: "struct UserOperation",
        components: [
          { name: "sender", type: "address", internalType: "address" },
          { name: "nonce", type: "uint256", internalType: "uint256" },
          { name: "initCode", type: "bytes", internalType: "bytes" },
          { name: "callData", type: "bytes", internalType: "bytes" },
          { name: "callGasLimit", type: "uint256", internalType: "uint256" },
          {
            name: "verificationGasLimit",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "preVerificationGas",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "maxFeePerGas", type: "uint256", internalType: "uint256" },
          {
            name: "maxPriorityFeePerGas",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "paymasterAndData", type: "bytes", internalType: "bytes" },
          { name: "signature", type: "bytes", internalType: "bytes" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "SpendRegistered",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "permissionHash",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "value",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  { type: "error", name: "ExceededSpendingLimit", inputs: [] },
  { type: "error", name: "InvalidWithdrawAsset", inputs: [] },
  { type: "error", name: "MustAssertSpendLastCall", inputs: [] },
  { type: "error", name: "SelectorNotAllowed", inputs: [] },
  { type: "error", name: "SpendValueOverflow", inputs: [] },
  { type: "error", name: "TargetNotAllowed", inputs: [] },
];
