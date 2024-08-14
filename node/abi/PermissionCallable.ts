export const permissionCallableAbi = [
    {
        type: "function",
        name: "permissionedCall",
        inputs: [{ name: "call", type: "bytes", internalType: "bytes" }],
        outputs: [{ name: "res", type: "bytes", internalType: "bytes" }],
        stateMutability: "payable",
    },
    {
        type: "function",
        name: "supportsPermissionedCallSelector",
        inputs: [{ name: "selector", type: "bytes4", internalType: "bytes4" }],
        outputs: [{ name: "", type: "bool", internalType: "bool" }],
        stateMutability: "view",
    },
    {
        type: "error",
        name: "AddressEmptyCode",
        inputs: [{ name: "target", type: "address", internalType: "address" }],
    },
    { type: "error", name: "FailedCall", inputs: [] },
    {
        type: "error",
        name: "NotPermissionCallable",
        inputs: [{ name: "selector", type: "bytes4", internalType: "bytes4" }],
    },
];
  