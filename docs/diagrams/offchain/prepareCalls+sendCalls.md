## Prepare Calls and Send Pre-Signed Calls

General flow for sending user operations with a Wallet Server. Supports server signers and our own Wallet A (see [sendCalls+permissionsContext](./sendCalls+permissionsContext.md)).

```mermaid
sequenceDiagram
    autonumber
    participant A as App
    box transparent Wallet
        participant WS as Wallet Server
        participant CS as Cosigner
    end
    box transparent External
        participant P as Paymaster
        participant B as Bundler
    end

    A->>WS: wallet_prepareCalls
    WS->>P: pm_getPaymasterStubData
    P-->>WS: paymaster stub data
    WS->>P: pm_getPaymasterData
    P-->>WS: paymaster data
    WS-->>A: prepared calls with hash
    A->>A: sign
    A->>WS: wallet_sendCalls
    Note over A,WS: preSigned capability with signature
    WS->>CS: cosign userOp
    CS->>CS: validate userOp + sign
    CS-->>WS: cosignature
    WS->>B: eth_sendUserOperation
    B-->>WS: userOpHash
    WS-->>A: callsId
```
