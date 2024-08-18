# Offchain Authorization

We want a mechanism to verify if a permission request comes the contract’s official app or a third-party interface. Phishing permission approvals could be a new attack vector that users are not used to and are more hidden to the user because now apps can sign transactions without informing users. Especially with the compounded risk of spending token approvals, we think it is important to let apps provide additional security.

Our approach is to add a new function to app smart contracts for offchain validation:

```solidity
enum Authorization {
    UNAUTHORIZED, // show warning + reject request
    UNVERIFIED, // show caution
    VERIFIED // show okay
}

function getRequestAuthorization(
  bytes32 requestHash,
  bytes calldata signature
) external view returns (Authorization);
```

When Coinbase Smart Wallet receives a permissions request, we check that if the request is signed and if so, ask the contract directly if the request is authorized. We switch on this return in our UI to indicate to users the relative trust they should have in the app requesting.

## Call sequence

1. App frontend determines their permissions request objects array
2. App frontend sends permissions to App backend
3. App backend generates nonce by reusing generateSiweNonce
4. App backend canonicalizes JSON format via RFC8785  
   a. This is required to get consistent hashes of the same JSON object
   b. canonicalize package recommended for Node
5. App backend creates requestHash via EIP-712 combining nonce and json

```tsx
import { hashTypedData } from "viem";

const permissionsHash = hashTypedData({
  domain: {
    name: "Grant Permissions",
    version: "1",
  },
  types: {
    Authorization: [
      { name: "nonce", type: "string" },
      { name: "json", type: "string" },
    ],
  },
  primaryType: "Authorization",
  message: {
    nonce: "",
    json: "",
  },
});
```

6. App backend does custom hash-wrapping if necessary (must match their onchain implementation)
7. App backend signs hash with their custodial key (e.g. AWS KMS)
8. App backend returns { permissionsHash, nonce, signature } to App frontend
9. App frontend submits wallet_grantPermissions with new policy

```tsx
type OffchainAuthorizationPolicy = {
  type: "offchain-authorization";
  data: {
    nonce: string;
    authorization: Hex;
  };
};
```

10. Wallet checks nonce has not yet been used
    a. stores nonce usage in wallet backend
    b. rely on generation entropy to not accidentally collide in happy-path
11. Wallet re-computes requestHash given nonce and permissions data.
12. Wallet calls getRequestAuthorization(requestHash, signature) on contract via offchain read call
    a. Returns `UNAUTHORIZED` -> show warning + reject request
    b. Returns `UNVERIFIED` -> show caution
    c. Returns `AUTHORIZED` -> show okay
    d. Reverts -> default `UNVERIFIED`
