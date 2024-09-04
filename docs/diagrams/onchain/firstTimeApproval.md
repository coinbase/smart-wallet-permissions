## First-Time Approval

Permissions require Smart Wallets to allow the Permission Manager as an owner to validate user operations.

When a user makes their first permission approval on a chain, we will do a transaction approval instead of a signature approval. In our call batch, we first self-call `addOwnerAddress` on the Smart Wallet to add the Permission Manager as an owner. The second call in the batch is to `PermissionManager.approvePermission` to approve the permission.

By doing a transaction approval for a chain's first-use, we are able to batch in the owner addition in the same passkey signature request to the user.

```mermaid
sequenceDiagram
    autonumber
    participant E as Entrypoint
    participant A as Account
    participant M as Permission Manager
    participant P as Permission Contract

    Note left of E: Validation phase
    E->>A: validateUserOp
    A-->>E: validation data
    Note left of E: Execution phase
    E->>A: executeBatch
    A->>A: addOwnerAddress
    Note over A: Add Permission Manager
    A->>M: approvePermission
    Note over A,M: permission struct
    M->>P: initializePermission
```
