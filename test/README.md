# Tests Overview

## Invariant List

1. `CoinbaseSmartWallet`
   1. Only transaction path impacted is when `PermissionManager` is used as owner
   1. Existing transaction paths work exactly the same
      1. Can transact using other owners
      1. Can remove `PermissionManager` as an owner
      1. Can add and remove other owners
      1. Can upgrade the contract
1. `PermissionManager`
   1. Can only validate signatures for ERC-4337 User Operations
      1. Only supports the same UserOp type as `CoinbaseSmartWallet` (v0.6)
   1. Cannot make direct calls to `CoinbaseSmartWallet` to prevent updating owners or upgrading implementation.
      1. Only one view call is allowed to `CoinbaseSmartWallet.isValidSignature` to check permission approval.
      1. Permissioned UserOps cannot make direct calls to `CoinbaseSmartWallet` to prevent updating owners or upgrading implementation.
   1. Only returns User Operations as valid when:
      1. `PermissionManager` is not paused
      1. UserOp is signed by Permission signer ("session key")
      1. UserOp is signed by cosigner or pending cosigner (managed by Coinbase)
      1. UserOp paymaster is enabled by `PermissionManager`
      1. UserOp and Permission are validated together by Permission Contract
      1. Permission Contract is enabled by `PermissionManager`
      1. Permission account matches UserOp sender
      1. Permission chain matches current chain
      1. Permission verifyingContract is `PermissionManager`
      1. Permission has not expired
      1. Permission is approved via storage or signature by a different owner on smart wallet
      1. Permission has not been revoked
   1. Only owner can update the owner
      1. Supports a 2-step process where the new owner must explictly acknowledge its ownership
   1. Only owner can update paused status
   1. Only owner can update enabled Permission Contracts
   1. Only owner can update enabled Paymasters
   1. Only owner can rotate cosigners
      1. Requires a 2-step process where the rotation does not accidentally reject in-flight UserOps
   1. Permissions can only be revoked by the account that it applies to
   1. Permissions can be approved via signature or transaction
      1. Via transaction, can only be approved by the account that it applies to or from anyone with a signature approval for that Permission from the account
      1. Via signature, can only be signed by the account itself
      1. Permissions are approved in storage lazily on first use
   1. Permissions can be batch approved and revoked separately and simultaneously
   1. Validations are 100% compliant with [ERC-7562](https://eips.ethereum.org/EIPS/eip-7562)
1. `PermissionCallableAllowedContractNativeTokenRecurringAllowance`
   1. Only allows spending native token up to a recurring allowance
      1. Includes spending on external contract calls
      1. Does not allow sending native token as direct transfer
      1. If UserOp spends X but also receives Y atomically, the spend registered is X independent of what Y is
      1. Requires using a paymaster
      1. Only resets recurring allowance when entering into a new cycle
   1. Allows withdrawing native token from `MagicSpend`
      1. Does not supports use as a paymaster
      1. Supports direct `withdraw`
      1. Withdraws are not accounted as "spending" because they just moving assets from a users offchain account to this onchain account
      1. Withdraws can be made with or without immediate spending in same-operation
      1. Does not allow withdrawing any other tokens (e.g. ERC20/ERC721/ERC1155)
   1. Besides `MagicSpend`, only allows external calls to a single allowed contract signed over by user
      1. Also can only use a single special selector (`permissionedCall(bytes)`) defined by `IPermissionCallable`
   1. Does not allow spending other tokens (e.g. ERC20/ERC721/ERC1155)
   1. Does not allow approving or revoking permissions
      1. Does allow one-time storage approval performed by `PermissionManager` on the used permission hash.
   1. Validations are 100% compliant with [ERC-7562](https://eips.ethereum.org/EIPS/eip-7562)
1. `PermissionCallable`
   1. Inherits `IPermissionCallable`
   1. Requires inheriting contracts to override supported-selectors function
   1. Adds default implementation for special selector which:
      1. Validates inner call selector is supported
      1. Accepts call arguments equivalent to calldata that could be sent as a valid call to the contract directly
      1. Can be overriden by inheriting contracts
