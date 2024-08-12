## Prepare Calls Hash and Send Signed Calls

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

    A->>WS: wallet_prepareCallsHash
    WS->>P: pm_getPaymasterStubData
    P-->>WS: paymaster stub data
    WS->>P: pm_getPaymasterData
    P-->>WS: paymaster data
    WS-->>A: calls hash with context
    A->>A: sign
    A->>WS: wallet_sendSignedCalls
    WS->>CS: cosign userOp
    CS->>CS: validate userOp + sign
    CS-->>WS: cosignature
    WS->>B: eth_sendUserOperation
    B-->>WS: userOpHash
    WS-->>A: callsId
```
