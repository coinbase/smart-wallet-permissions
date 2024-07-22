1. App->SDK: request `wallet_grantPermissions`

```
[
    {
        account: "0x...",
        chainId: 84532,
        expiry: 1577840461,
        signer: {
            type: "passkey",
            data: {
                "publicKey": "0x...",
                "credentialId": "...",
            }
        },
        permission: {
            type: "call-with-permission",
            data: {},
        },
        policies: [
            {
                type: "native-token-spend-limit",
                data: {
                    allowance: "0x100",
                },
            }
        ]
    }
]
```

2. SDK->`keys.`: request `wallet_grantPermissions`

```
[
    {
        account: "0x...",
        chainId: 84532,
        expiry: 1577840461,
        signer: {
            type: "passkey",
            data: {
                "publicKey": "0x...",
                "credentialId": "...",
            }
        },
        permission: {
            type: "call-with-permission",
            data: {},
        },
        policies: [
            {
                type: "native-token-spend-limit",
                data: {
                    allowance: "0x100",
                },
            }
        ]
    }
]
```

3. `keys.`->User: prompt add `PermissionManager`

4. User->`keys.`: sign `userOpHash` to approve

5. `keys.`: Submit bundle to enable `PermissionManager`

6. `keys.`->User: prompt Approve Permission

7. User->`keys.`: sign `permissionHash` to approve

8. `keys.`->SDK: response `wallet_grantPermissions` (complete step #2)

```
[
    {
        // same fields as the request object
        ...grantPermission
        // add one more new field for "context" bytes
        context: '0x...',
    }
]
```

9. SDK->App: response `wallet_grantPermissions` (complete step #1)

```
[
    {
        // same fields as the request object
        ...grantPermission
        // add one more new field for "context" bytes
        context: '0x...',
    }
]
```
