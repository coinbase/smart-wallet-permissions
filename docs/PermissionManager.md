# Permission Manager

View a sample sequence diagram of onchain validation [here](./diagrams/onchain/permissionedCalls.md).

This page summarizes key design decisions for [`PermissionManager`](../src/PermissionManager.sol).

## Design Overview

### Immutable singleton

Some security mechanisms require storing state external to Smart Wallets. Given that some state applies to the system as a whole, designing around a singleton architecture was most intuitive. Given this contract will be added as an owner to all Smart Wallets that opt-in, it is vital that this contract be non-upgradeable to mitigate the risk of mass attacks to our users by swapping into a malicious implementation. However, this singleton is not permissionless and has a single `owner` to manage its safe operation.

### Ethereum address and `secp256r1` signers

Just like Smart Wallet V1, Session Keys supports both Ethereum address and `secp256r1` signers. Ethereum addresses are split into validating EOA signatures with `ecrecover` and contract signatures with [ERC-1271](https://eips.ethereum.org/EIPS/eip-1271) `isValidSignature`. The `secp256r1` curve supports both Passkey and [CryptoKey](./CryptoKey.md) signature validation through [WebAuthn](https://github.com/base-org/webauthn-sol/blob/main/src/WebAuthn.sol).

### Signature approvals with lazy caching

Users approve permissions by signing over the hash of a `struct Permission`. A signature-first approach enables users to approve without spending any gas upfront and delaying gas fees until the point of transaction. This helps create an environment where users feel more comfortable approving permissions by removing an immediate cost to them. However, doing a signature validation onchain is expensive so Permission Manager implements a lazy caching mechanism that saves the approval in storage during first use. On future use of the same permission, a signature validation can be skipped by reading this storage, substantially improving gas efficiency. The storage for appovals is a doubly-nested mapping where the final key is the account address to enable valid access in the ERC-4337 validation phase.

### Transaction approvals

A storage-based approval system also enables Permission Manager to expose an `approvePermission` function that unlocks important UX primitives like [batch approvals](./diagrams/onchain/batchApprovePermissions.md) and [atomic updates](./diagrams/onchain/batchUpdatePermissions.md).

### Permission revocations

Permission Manager also exposes a `revokePermission` function to enable revocations. The storage for revocations is a doubly-nested mapping where the final key is the account address to enable valid access in the ERC-4337 validation phase. Permission revocation is always available to users in their Smart Wallet settings and in the future, potentially exposed to apps.

### Reentrancy protection

One important invariant for Permission Manager is that it should not enable any Session Key to change owners or upgrade the account implementation. The functions to do so on Smart Wallet are gated by an `onlyOwner` modifier which requires attempts to change owners or implementation to come from an owner of the Smart Wallet or the Smart Wallet itself. To prevent the latter case, Permission Manager loops over all calls in the batch (parsed from `userOp.calldata`) and ensures that no call's target is the Smart Wallet (`userOp.sender`). To prevent the former case, all contracts written by Coinbase are given additional scrutiny to have tightly defined paths for owner or implementation changes so that they cannot be called with Session Keys. External teams that build on Smart Wallet should be mindful of this development. Read more about this protection in Coinbase's internal audit.

Additionally, reentrancy calls to the Permission Manager are also negated to prevent cases where Session Keys attempt to approve new permissions or revoke others.

### Validation/Execution phase separation (`beforeCalls`)

[ERC-7562](https://eips.ethereum.org/EIPS/eip-7562) defines a set of conditions for ERC-4337's validation phase. Two limitations we need to work around are:

1. Accessing the `TIMESTAMP` opcode to check if a permission has expired
2. Reading `"associated storage"` to check common invariants (described in following sections)

To retain compliance, Permission Manager moves these checks to execution phase by enforcing that the first call in a batch is to `PermissionManager.beforeCalls`. This function implements the checks that cannot be done in validation phase and if it reverts, the user operation fails and no intended calls execute. The bundler will still get paid in this scenario because this is happening after validation phase.

### Enabled Permission Contracts and Paymasters

Part of these execution phase checks include verifying the attempted Permission Contract and Paymaster are enabled. The `owner` is responsible for maintaining this storage by adding new Permission Contracts as new functionality is rolled out, potentially disabling them later on if a compromise is found, and supporting ecosystem partners in adding their Paymasters to this allowlist.

### Permission initialization

The final step in `beforeCalls` is to apply to lazy approval caching mentioned earlier. If a permission has not yet been approved, it is then marked as approved in storage and an external call to `PermissionContract.initializePermission` is made. This one-time initialization is enforced to only come from the Permission Manager and optionally stores part or all of the values of the permission. For example, our first Permission Contract stores the native token recurring allowance parameters.

### Permission hash incompatibility with EIP-191 and EIP-712

Helping users be informed about the permissions requested of them is critical for a practically safe system. In addition to intentional design on our pop-up window, we disable the ability to get around our hot path by making the permission hash message incompatible with [EIP-191](https://eips.ethereum.org/EIPS/eip-191) and [EIP-712](https://eips.ethereum.org/EIPS/eip-712). This prevents apps from secretely asking users to approve a permission through an interface that does not sufficiently communicate what the user is actually signing.

### Normal transaction flow prevention

On this same theme, we prevent apps from secretly adding calls to `PermissionManager.beforeCalls`, `PermissionManager.approvePermission`, and `PermissionManager.revokePermission` in their call batches through normal transaction requests. We add new simulation on the `eth_sendTransaction` and `wallet_sendCalls` RPCs to look for any call to `PermissionManager` and auto-reject if present.

### Required Cosigner

All permissioned user operations require additional offchain validation through another signature from a Coinbase-owned key. This cosigner is our final line of protection to filter out user operations that might negatively impact users. It's logic is outlined further [here](./Cosigner.md) and is recommended to read after covering the Permission Contract's mechanisms: [recurring allowances](./RecurringAllowance.md), [permissioned calls](./PermissionedCall.md), and [required paymasters](./PaymasterRequirement.md).
