export const permissionContractAbi = [
  {
    type: "constructor",
    inputs: [
      {
        name: "permissionManager_",
        type: "address",
        internalType: "address",
      },
      { name: "magicSpend_", type: "address", internalType: "address" },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getRecurringAllowance",
    inputs: [
      { name: "account", type: "address", internalType: "address" },
      { name: "permissionHash", type: "bytes32", internalType: "bytes32" },
    ],
    outputs: [
      {
        name: "recurringAllowance",
        type: "tuple",
        internalType: "struct NativeTokenRecurringAllowance.RecurringAllowance",
        components: [
          { name: "start", type: "uint48", internalType: "uint48" },
          { name: "period", type: "uint48", internalType: "uint48" },
          { name: "allowance", type: "uint160", internalType: "uint160" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRecurringAllowanceUsage",
    inputs: [
      { name: "account", type: "address", internalType: "address" },
      { name: "permissionHash", type: "bytes32", internalType: "bytes32" },
    ],
    outputs: [
      {
        name: "cycleUsage",
        type: "tuple",
        internalType: "struct NativeTokenRecurringAllowance.CycleUsage",
        components: [
          { name: "start", type: "uint48", internalType: "uint48" },
          { name: "end", type: "uint48", internalType: "uint48" },
          { name: "totalSpend", type: "uint160", internalType: "uint160" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "initializePermission",
    inputs: [
      { name: "account", type: "address", internalType: "address" },
      { name: "permissionHash", type: "bytes32", internalType: "bytes32" },
      { name: "permissionValues", type: "bytes", internalType: "bytes" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "magicSpend",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "permissionManager",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "useRecurringAllowance",
    inputs: [
      { name: "permissionHash", type: "bytes32", internalType: "bytes32" },
      { name: "spend", type: "uint256", internalType: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "validatePermission",
    inputs: [
      { name: "permissionHash", type: "bytes32", internalType: "bytes32" },
      { name: "permissionValues", type: "bytes", internalType: "bytes" },
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
    name: "RecurringAllowanceInitialized",
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
        name: "recurringAllowance",
        type: "tuple",
        indexed: false,
        internalType: "struct NativeTokenRecurringAllowance.RecurringAllowance",
        components: [
          { name: "start", type: "uint48", internalType: "uint48" },
          { name: "period", type: "uint48", internalType: "uint48" },
          { name: "allowance", type: "uint160", internalType: "uint160" },
        ],
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RecurringAllowanceUsed",
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
        name: "cycleStart",
        type: "uint48",
        indexed: false,
        internalType: "uint48",
      },
      {
        name: "cycleEnd",
        type: "uint48",
        indexed: false,
        internalType: "uint48",
      },
      {
        name: "spend",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  { type: "error", name: "BeforeRecurringAllowanceStart", inputs: [] },
  { type: "error", name: "ExceededRecurringAllowance", inputs: [] },
  { type: "error", name: "InvalidInitializePermissionSender", inputs: [] },
  { type: "error", name: "InvalidUseRecurringAllowanceCall", inputs: [] },
  { type: "error", name: "InvalidWithdrawAsset", inputs: [] },
  { type: "error", name: "SelectorNotAllowed", inputs: [] },
  { type: "error", name: "SpendValueOverflow", inputs: [] },
  { type: "error", name: "TargetNotAllowed", inputs: [] },
  { type: "error", name: "ZeroRecurringAllowance", inputs: [] },
];
