## Deployed Account User Operation Validation

```mermaid
sequenceDiagram
    autonumber
    participant E as Entrypoint
    participant M as Permission Manager
    participant A as Smart Wallet
    participant P as Permission Contract
    participant C as External Contract

    Note left of E: Validation phase
    E->>M: validateUserOp
    Note over M: General permission checks
    opt
        M->>A: isValidSignature
        Note over M,A: check account approval signature
        A-->>M: EIP1271 magic value
        M->>P: initializePermission
    end
    M->>P: validatePermission
    Note over P: Specific permission checks
    M-->>E: validation data
    Note left of E: Execution phase
    E->>M: executeBatch
    M->>A: executeBatch
    loop
        A->>C: permissionedCall
        Note over C,A: send intended calldata wrapped with special selector
    end
    A->>P: useRecurringAllowance
    Note over P: assert spend within recurring allowance
```
