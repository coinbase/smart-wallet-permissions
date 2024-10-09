# Spend Permissions RPC

## `wallet_grantSpendPermissions`

```tsx
type SpendPermissionRequest = {
  chainId: Hex;
  account: Address;
  spender: Address;
  start?: number;
  end?: number;
  period?: number;
  allowances: {
    token: Address;
    value: Hex;
    tokenId?: Hex;
  }[];
};

type SpendPermissionResponse = {
  grantedPermissions: SpendPermissionRequest;
  context: Hex;
  initCode?: {
    factory: Address;
    factoryData: Hex;
  };
};
```

### Grouped with consistent timeframes

We've noticed a need to simplify the request to users by having consistent timeframes for all the tokens requested of them.

- `start` is optional and if not provided, defaults to the current time
- `end` is optional and if not provided, defaults to never expiring
- `period` is optional and if not provided, defaults to a single period with no recurring logic

### Standard allowances

In combination with a set of time parameters, `allowances` describe which tokens can be spent on this timeframe by the `spender`.

- `token` is the contract address, with `address(0)` to represent native token
- `value` is the amount of tokens allowed
- `tokenId` is optional and is used to define a specific NFT id within a collection

### Context return

Arbitrary bytes context is a convenient pattern to abstract away contract-specific details and is kept over from ERC-7715.

### Account initCode

Accounts granting spend permissions may not yet be deployed so the wallet gives the app this additional data so that it can deploy the account when attempting to use a spend permission.
