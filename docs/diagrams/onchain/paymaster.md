# Use Spend Permissions with a Paymaster

Using Spend Permissions with a Paymaster enables spending a recurring allowance on gas so that the spender does not need to have gas in their account to initiate a withdraw.

```mermaid
sequenceDiagram
    autonumber
    participant E as Entrypoint
    participant S as Spender
    participant P as Paymaster
    participant SP as Spend Permissions
    participant U as Smart Wallet

    Note over E: Setup Transaction
    S->>SP: updateDelegateSpender(paymaster, true)
    Note over E: Validation phase
    E->>S: validateUserOp
    E->>P: validatePaymasterUserOp
    Note over E: Execution phase
    E->>S: executeBatch
    E->>P: postOp
    P->>SP: withdraw
    SP->>U: execute(transfer)
    U->>P: call{value}()
```
