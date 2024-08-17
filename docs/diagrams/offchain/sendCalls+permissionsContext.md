## Send Calls with Permissions Context Capability

```mermaid
sequenceDiagram
    autonumber
    box transparent App
        participant A as App Interface
        participant SDK as Wallet SDK
    end
    box transparent Wallet
        participant WS as Wallet Server
        participant CS as Cosigner
    end
    box transparent External
        participant P as Paymaster
        participant B as Bundler
    end

    A->>SDK: wallet_sendCalls
    SDK->>WS: wallet_prepareCalls
    WS->>P: pm_getPaymasterStubData
    P-->>WS: paymaster stub data
    WS->>P: pm_getPaymasterData
    P-->>WS: paymaster data
    WS-->>SDK: prepared calls with hash
    SDK->>SDK: sign
    SDK->>WS: wallet_sendCalls
    Note over SDK,WS: preSigned capability with signature
    WS->>CS: cosign userOp
    CS->>CS: validate userOp and sign
    CS-->>WS: cosignature
    WS->>B: eth_sendUserOperation
    B-->>WS: userOpHash
    WS-->>SDK: callsId
    SDK-->>A: callsId
```
