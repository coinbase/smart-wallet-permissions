# Smart Wallet Permissions Docs

These docs are meant to walk you through the key design decisions and mechanisms that underly the Smart Wallet Permissions V1 contracts.

- apps can now request permissions from wallets using [ERC-7715](./ERC-7715.md)
- wallets are responsible for preparing a context that can be used to authorize account actions
- user approves some permissions to an app-owned signer which can then take actions
- our first design iteration leans into existing 4337 patterns and infrastructure
- one goal is to support permissions without upgrading the core Coinbase Smart Wallet account implementation
- we accomplish this by adding a new smart contract as an owner of smart wallets that enables the permissions feature called [PermissionsManager](./PermissionManager.md)
- [image of contract diagrams with PermissionsManager in auth flow]
- PermissionsManager is responsible for authenticating permissioned user operations for accounts
- There are many kinds of permissions that we expect to support over time, so we leaned into a modular design where permission-specific checks are delegated to a set of permission contracts
- These permission contracts implement specific controls and trust that the manager has already made the most fundamental guarantees
- [image of contract diagrams]

For the V1 launch, we will only support one permission contract with the goals of:

- spend native token (ETH) via a [recurring allowance](./RecurringAllowance.md)
- call external contracts
- support MagicSpend withdraws

This new paradigm of apps submitting transactions on behalf of users is new ground and security is most important which led us to three security features:

- external contracts can only be called through a [single selector, `permissionedCall(bytes)`](./PermissionedCall.md)
- apps [must use a paymaster](./PaymasterRequirement.md) to front transaction costs
- all permissioned user operations must be [cosigned by Coinbase](./Cosigner.md)
