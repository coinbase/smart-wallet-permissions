# Use Spend Permissions as a Paymaster

Using Spend Permissions as a Paymaster enables spending a recurring allowance on gas so that the spender does not need to have gas in their account to initiate a withdraw. Native token in excess of gas payment can be withdrawn simultaneously and withdrawing ERC-20s must be done with the explicit `withdraw` call in execution phase.

```mermaid
sequenceDiagram
    autonumber
    participant E as Entrypoint
    participant S as Spender
    participant SP as Spend Permissions
    participant U as Smart Wallet

    Note over E: Validation phase
    E->>S: validateUserOp
    E->>SP: validatePaymasterUserOp
    SP->>U: execute(paymasterDeposit)
    U->>SP: paymasterDeposit
    SP->>E: deposit
    Note over SP,E: Deposit required prefund
    Note over E: Execution phase
    E->>S: executeBatch
    opt
        S->>SP: withdrawGasExcess
        SP->>S: call{value}()
    end
    E->>SP: postOp
    opt
        SP->>E: withdrawTo
        E->>S: call{value}()
        Note over E,S: Refund unused gas
    end
```
