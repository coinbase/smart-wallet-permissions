## Cache Permissions

After permission approval signatures are exposed publicly, anyone can use that signature to save the approval in storage. Doing so can save gas as it removes the additional signature calldata and external call + validation of the signature.

```mermaid
sequenceDiagram
    autonumber
    participant E as External
    participant M as Permission Manager
    participant P as Permission Contract

    E->>M: approvePermission
    Note over E,M: permission struct
    M->>P: initializePermission
```
