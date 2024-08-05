## Get Active Permissions

```mermaid
sequenceDiagram
    App->>SDK: wallet_getActivePermissions
    SDK->>Wallet Server: wallet_getActivePermissions
    Wallet Server->>SDK: permissions
    SDK->>App: permissions
```
