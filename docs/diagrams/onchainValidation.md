## Onchain Validation

```mermaid
sequenceDiagram
    autonumber
    participant E as Entrypoint
    participant A as Account
    participant M as Permission Manager
    participant P as Permission Contract
    participant C as External Contract
    %% participant S as Permission Signer
    %% participant W as WebAuthn

    E->>A: validateUserOp
    Note left of E: Validation phase
    A->>M: isValidSignature
    Note over A,M: check owner signed userOp
    M->>A: isValidSignature
    Note over M,A: check account approved permission
    A-->>M: EIP1271 magic value
    Note over M: General permission checks: ‎ ‎ ‎  <br/> 1. permission not revoked ‎  ‎ ‎ ‎ ‎ <br/> 2. session key signed userOp ‎ <br/> 3. prepends checkBeforeCalls <br/> 4. no calls back on account ‎ ‎ ‎
    %% alt
    %%     M->>M: ecrecover
    %%     Note over M: validate EOA signature <br/>of user operation by session key
    %% else
    %%     M->>S: isValidSignature
    %%     Note over M,S: validate contract signature of user operation by session key
    %%     S-->>M: EIP1271 magic value
    %% else
    %%     M->>W: verify
    %%     Note over M,W: validate P256 signature of user operation by session key
    %%     W-->>M: verified
    %% end
    M->>P: validatePermission
    Note over P: Specific permission checks: ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 1. only calls allowed contracts ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 2. only calls special selector ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ ‎ <br/> 3. appends assert call if spending ETH
    %% Note over M: General permission checks: ‎ ‎ ‎ <br/> 3. packs pre/post check calls <br/> 4. no calls back on account ‎ ‎ ‎
    M-->>A: EIP1271 magic value
    A-->>E: validation data
    %% deactivate M
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
