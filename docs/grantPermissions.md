```mermaid
sequenceDiagram
    App->>SDK: wallet_grantPermissions
    SDK->>Wallet: wallet_grantPermissions
    Wallet->>User: Approve Permission
    User->>User: Sign
    User->>Wallet: Signature
    Wallet->>SDK: Permissions & context
    SDK->>App: Permissions & context
```
