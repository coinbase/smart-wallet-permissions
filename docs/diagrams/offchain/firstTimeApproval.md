## First-Time Approval

Permissions require Smart Wallets to allow the Permission Manager as an owner to validate user operations.

When a user makes their first permission approval on a chain, we will do a transaction approval instead of a signature approval. In our call batch, we first self-call `addOwnerAddress` on the Smart Wallet to add the Permission Manager as an owner. The second call in the batch is to `PermissionManager.approvePermission` to approve the permission.

By doing a transaction approval for a chain's first-use, we are able to batch in the owner addition in the same passkey signature request to the user.

```mermaid
sequenceDiagram
    autonumber
    box transparent App
        participant A as App Interface
        participant SDK as Wallet SDK
    end
    box transparent Wallet
        participant W as Wallet Interface
        participant U as User
    end
    box transparent External
        participant P as Paymaster
        participant B as Bundler
    end

    A->>SDK: wallet_grantPermissions
    SDK->>W: wallet_grantPermissions
    W->>P: pm_getPaymasterStubData
    P-->>W: paymaster stub data
    W->>P: pm_getPaymasterData
    P-->>W: paymaster data
    W->>U: approve permission
    Note over W,U: userOp with owner addition
    U->>U: sign
    U-->>W: signature
    W->>B: eth_sendUserOperation
    B-->>W: userOpHash
    W-->>SDK: permissions with context
    SDK-->>A: permissions with context
```
