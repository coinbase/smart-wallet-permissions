# Smart Wallet Permissions

**Permissions enable apps to submit transactions on behalf of users.**

Permissioned transactions can avoid typical user friction in web3 apps like:

- Wallet popup windows
- Passkey biometric scans
- User presence in-app

Permissions unlock experiences that keep all of the unique properties of wallets (self-custody, data portability, etc.) without sacrificing on user experience compared to web2:

- Sign-in and never see mention of a wallet again
- High-frequency transactions (gaming, social, etc.)
- Background transactions (automated trading, subscriptions, etc.)

## Get started

> **Note**: These contracts are currently unaudited and are only recommended for testing purposes. Use at your own risk.

Read about how to [get started here](./docs/examples/).

## Sample flows

Coinbase is actively contributing to [ERC-7715](https://eip.tools/eip/7715) which is the intended way to use Smart Wallet Permissions.

### 1. Grant permissions

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
    end

    A->>SDK: wallet_grantPermissions
    SDK->>W: wallet_grantPermissions
    W->>U: approve permission
    U->>U: sign
    U-->>W: signature
    W-->>SDK: permissions with context
    SDK-->>A: permissions with context
```

### 2. Prepare, sign, and send calls

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
    Note over A,WS: permissions capability with context
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
