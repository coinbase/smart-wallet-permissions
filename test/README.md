# Tests Overview

## Full Invariant List

1. `CoinbaseSmartWallet`
   1. Only transaction path impacted is when `PermissionManager` is used as owner
   2. Existing transaction paths work exactly the same
      1. Can transact using other owners
      2. Can remove `PermissionManager` as an owner
      3. Can add and remove other owners
      4. Can upgrade the contract
2. `PermissionManager`
   1. Can only validate signatures for ERC-4337 User Operations
      1. Only supports the same UserOp type as `CoinbaseSmartWallet` (v0.6)
   2. Cannot make direct calls to `CoinbaseSmartWallet` to prevent updating owners or upgrading implementation.
      1. Only one view call is allowed to `CoinbaseSmartWallet.isValidSignature` to check permission approval.
      2. Permissioned UserOps cannot make direct calls to `CoinbaseSmartWallet` to prevent updating owners or upgrading implementation.
   3. Only returns User Operations as valid when:
      1. `PermissionManager` is not paused
      2. UserOp is signed by Permission signer ("session key")
      3. UserOp is signed by cosigner or pending cosigner (managed by Coinbase)
      4. UserOp paymaster is enabled by `PermissionManager`
      5. UserOp and Permission are validated together by Permission Contract
      6. Permission Contract is enabled by `PermissionManager`
      7. Permission account matches UserOp sender
      8. Permission chain matches current chain
      9. Permission verifyingContract is `PermissionManager`
      10. Permission has not expired
      11. Permission is approved via storage or signature by a different owner on smart wallet
      12. Permission has not been revoked
   4. Only owner can update the owner
      1. Supports a 2-step process where the new owner must explictly acknowledge its ownership
   5. Only owner can update paused status
   6. Only owner can update enabled Permission Contracts
   7. Only owner can update enabled Paymasters
   8. Only owner can update if a Paymaster's gas spend should be added to the total spend (support potentially many `MagicSpend` contracts)
   9. Only owner can rotate cosigners
      1. Requires a 2-step process where the rotation does not accidentally reject in-flight UserOps
   10. Permissions can only be revoked by the account that it applies to
   11. Permissions can be approved via signature or transaction
       1. Via transaction, can only be approved by the account that it applies to or from anyone with a signature approval for that Permission from the account
       2. Via signature, can only be signed by the account itself
       3. Permissions are approved in storage lazily on first use
   12. Permissions can be batch approved and revoked separately and simultaneously
   13. Validations are 100% compliant with [ERC-7562](https://eips.ethereum.org/EIPS/eip-7562)
3. `PermissionCallableAllowedContractNativeTokenRecurringAllowance`
   1. Only allows spending native token up to a recurring allowance
      1. Includes spending on external contract calls
      2. Includes spending on gas if cost incurred by user
      3. Does not allow sending native token as direct transfer
      4. If UserOp spends X but also receives Y atomically, the spend registered is X independent of what Y is
   2. Allows withdrawing native token from `MagicSpend`
      1. Supports direct `withdraw` or `withdrawGasExcess` cases (used for just-in-time funds or as a Paymaster)
      2. Withdraws are not accounted as "spending" because they just moving assets from a users offchain account to this onchain account
      3. Withdraws can be made with or without immediate spending in same-operation
      4. Does not allow withdrawing any other tokens (e.g. ERC20/ERC721/ERC1155)
   3. Besides `MagicSpend`, only allows external calls to a single allowed contract signed over by user
      1. Also can only use a single special selector (`permissionedCall(bytes)`) defined by `IPermissionCallable`
   4. Does not allow spending other tokens (e.g. ERC20/ERC721/ERC1155)
   5. Does not allow approving or revoking permissions
      1. Does allow one-time storage approval performed by `PermissionManager` on the used permission hash.
   6. Validations are 100% compliant with [ERC-7562](https://eips.ethereum.org/EIPS/eip-7562)
4. `PermissionCallable`
   1. Inherits `IPermissionCallable`
   2. Requires inheriting contracts to override supported-selectors function
   3. Adds default implementation for special selector which:
      1. Validates inner call selector is supported
      2. Accepts call arguments equivalent to calldata that could be sent as a valid call to the contract directly
      3. Can be overriden by inheriting contracts
