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

## Sample flows

### 1. Grant permissions (offchain)

```mermaid
sequenceDiagram
    autonumber
    participant A as App
    participant SDK as SDK
    participant W as Wallet
    participant U as User

    A->>SDK: wallet_grantPermissions
    SDK->>W: wallet_grantPermissions
    W->>U: approve permission
    U->>U: sign
    U-->>W: signature
    W-->>SDK: permissions with context
    SDK-->>A: permissions with context
```

### 2. Get active permissions (offchain)

```mermaid
sequenceDiagram
    autonumber
    participant A as App
    participant SDK as SDK
    participant WS as Wallet Server

    A->>SDK: wallet_getActivePermissions
    SDK->>WS: wallet_getActivePermissions
    WS-->>SDK: permissions with context
    SDK-->>A: permissions with context
```

### 3. Send calls with `permissions.context` capability

```mermaid
sequenceDiagram
    autonumber
    participant A as App
    participant SDK as SDK
    participant WS as Wallet Server
    participant P as Paymaster
    participant CS as Cosigner
    participant B as Bundler

    A->>SDK: wallet_sendCalls
    SDK->>WS: wallet_fillUserOp
    WS->>P: pm_getPaymasterStubData
    P-->>WS: paymaster stub data
    WS->>P: pm_getPaymasterData
    P-->>WS: paymaster data
    WS-->>SDK: filled userOp
    SDK->>SDK: sign
    Note right of SDK: signing with CryptoKey P256
    SDK->>WS: wallet_sendUserOpWithSignature
    WS->>CS: cosign userOp
    CS->>CS: validate userOp + sign
    CS-->>WS: cosignature
    WS->>B: eth_sendUserOperation
    B-->>WS: userOpHash
    WS-->>SDK: callsId
    SDK-->>A: callsId
```

### 4. Validate user operation (onchain)

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
    Note over M: General permission checks: ‎ ‎ ‎  <br/> 1. permission not revoked ‎  ‎ ‎ ‎ ‎ <br/> 2. session key signed userOp ‎ <br/> 3. prepends checkBeforeCalls <br/> 4. no calls back on account ‎ ‎ ‎
    M->>P: validatePermission
    Note over P: Specific permission checks: ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 1. only calls allowed contracts ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 2. only calls special selector ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 3. appends assert call if spending ETH
    M-->>A: EIP1271 magic value
    A-->>E: validation data
    E->>A: executeBatch
    Note left of E: Execution phase
    A->>M: checkBeforeCalls
    Note over M: Execution phase checks: ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎  <br/> 1. manager not paused ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 2. permission contract enabled <br/> 3. cosigner signed userOp ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 4. permission not expired ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎
    loop
        A->>C: permissionedCall
        Note over C,A: send intended calldata wrapped with special selector
    end
    opt
        A->>P: assertSpend
        Note over A,P: assert spend within rolling limit
    end
```

