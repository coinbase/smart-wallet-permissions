1. App->SDK: request `wallet_grantPermissions`

```
{
    account: "0x...",
    chainId: 84532,
    expiry: 1577840461,
    signer: {
        type: "wallet",
    },
    permissions: [
        {
            required: true,
            type: "session-call",
            data: {},
            policies: [
                {
                    type: "native-token-spend-limit",
                    data: {
                        value: "0x100",
                    },
                }
            ]
        }
    ]
}
```

2. SDK->`keys.`: request `wallet_grantPermissions`

```
// only change is from signer (wallet -> passkey)
{
    account: "0x...",
    chainId: 84532,
    expiry: 1577840461,
    signer: {
        type: "key",
        data: {
            id: "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"
        }
    },
    permissions: [
        {
            required: true,
            type: "session-call",
            data: {},
            policies: [
                {
                    type: "native-token-spend-limit",
                    data: {
                        value: "0x100",
                    },
                }
            ]
        }
    ]
}
```

3. `keys.`->User: prompt add `SessionManager`

4. User->`keys.`: sign `userOpHash` to approve

5. `keys.`: Submit bundle to add `SessionManager`

6. `keys.`->User: prompt Approve Session

7. User->`keys.`: sign `permissionHash` to approve

8. `keys.`->SDK: response `wallet_grantPermissions` (complete step #2)

```
{
    expiry: 1577840461,
    permissionsContext: '0x...',
    grantedPermissions: [
        {
            required: true,
            type: 'session-call',
            data: {},
            policies: [
                {
                    type: 'native-token-spend-limit',
                    data: {
                        value: '0x...',
                    },
                }
            ]
        }
    ]
}
```

9. SDK->App: response `wallet_grantPermissions` (complete step #1)

```
{
    expiry: 1577840461,
    permissionsContext: '0x...',
    grantedPermissions: [
        {
            required: true,
            type: 'session-call',
            data: {},
            policies: [
                {
                    type: 'native-token-spend-limit',
                    data: {
                        value: '0x...',
                    },
                }
            ]
        }
    ]
}
```
