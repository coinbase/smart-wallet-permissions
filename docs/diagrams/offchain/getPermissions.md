## Get Permissions

```mermaid
sequenceDiagram
    autonumber
    box transparent App
        participant A as App Interface
        participant SDK as Wallet SDK
    end
    participant WS as Wallet Server

    A->>SDK: wallet_getPermissions
    SDK->>WS: wallet_getPermissions
    WS-->>SDK: permissions with context
    SDK-->>A: permissions with context
```
