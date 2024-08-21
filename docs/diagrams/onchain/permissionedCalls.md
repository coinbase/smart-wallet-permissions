## User Operation Validation

```mermaid
sequenceDiagram
    autonumber
    participant E as Entrypoint
    participant A as Account
    participant M as Permission Manager
    participant P as Permission Contract
    participant C as External Contract

    E->>A: validateUserOp
    Note left of E: Validation phase
    A->>M: isValidSignature
    Note over A,M: check owner signed userOp
    M->>A: isValidSignature
    Note over M,A: check account approved permission
    A-->>M: EIP1271 magic value
    Note over M: General permission checks: ‎ ‎ <br/> 1. permission not revoked ‎  ‎ ‎ ‎ <br/> 2. user approved permission <br/> 3. session key signed userOp <br/> 4. prepends beforeCalls call ‎ <br/> 5. no calls back on account ‎ ‎
    M->>P: validatePermission
    Note over P: Specific permission checks: ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 1. only calls allowed contracts ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 2. only calls special selector ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 3. appends useRecurringAllowance call
    M-->>A: EIP1271 magic value
    A-->>E: validation data
    E->>A: executeBatch
    Note left of E: Execution phase
    A->>M: beforeCalls
    Note over M: Execution phase checks: ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎  <br/> 1. manager not paused ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 2. permission not expired ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 3. permission contract enabled <br/> 4. paymaster enabled  ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎<br/> 5. cosigner signed userOp ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎
    opt
        M->>P: initializePermission
    end
    loop
        A->>C: permissionedCall
        Note over C,A: send intended calldata wrapped with special selector
    end
    A->>P: useRecurringAllowance
    Note over P: assert spend within recurring allowance
    P->>M: shouldAddPaymasterGasToTotalSpend
    M-->>P: bool addGasSpend
    Note over P: add gas to total spend
```
