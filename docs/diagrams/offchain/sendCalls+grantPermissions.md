## Send Calls with Grant Permissions Capability

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
        participant WS as Wallet Server
    end
    box transparent External
        participant P as Paymaster
        participant B as Bundler
    end

    A->>SDK: wallet_sendCalls
    SDK->>W: wallet_sendCalls
    W->>P: pm_getPaymasterStubData
    P-->>W: paymaster stub data
    W->>P: pm_getPaymasterData
    P-->>W: paymaster data
    W->>U: approve transaction
    U->>U: sign
    U-->>W: signature
    W->>B: eth_sendUserOperation
    B-->>W: userOpHash
    opt if capabilities.permissions.request
    W->>U: approve permission
    U->>U: sign
    U-->>W: signature
    W->>WS: save approved permission
    end
    W-->>SDK: callsId
    SDK-->>A: callsId
```
