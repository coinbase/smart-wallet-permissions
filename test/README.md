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
   2. Cannot update `CoinbaseSmartWallet` owners
   3. Cannot upgrade `CoinbaseSmartWallet` implementation
   4. Cannot make self-calls on `CoinbaseSmartWallet` as a precaution
   5. Only returns User Operations as valid when:
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
   6. Only owner can change owner through a 2-step process
   7. Only owner can update paused status
   8. Only owner can update enabled Permission Contracts
   9. Only owner can update enabled Paymasters
   10. Only owner can update if a Paymaster's gas spend should be added to the total spend (support potentially many `MagicSpend` contracts)
   11. Only owner can rotate cosigners
   12. Cosigners can be rotated without accidentally rejecting in-flight UserOps
   13. Permissions can only be revoked by the account that it applies to
   14. Permissions can be approved via signature or transaction
       1. Via transaction, can only be approved by the account that it applies to or from anyone with a signature approval for that Permission from the account
       2. Via signature, can only be signed by the account itself
       3. Permissions cannot be approved if they have already been revoked
   15. Permissions can be batch approved and revoked separately and simultaneously
   16. Validations are 100% compliant with ERC-4337
3. `NativeTokenRollingSpendLimit`
   1. Only allows spending native token up to a rolling limit
      1. Includes spending on external contract calls
      2. Includes spending on gas if cost incurred by user
      3. Does not allow sending native token as direct transfer
      4. If UserOp spends X but also receives Y atomically, the spend registered is X independent of what Y is
   2. Allows withdrawing native token from `MagicSpend`
      1. Supports direct `withdraw` or `withdrawGasExcess` cases (used for JIT funds or as a Paymaster)
      2. Withdraws are not accounted as "spending" because they just moving assets from a users offchain account to this onchain account
      3. Does not allow withdrawing any other tokens (e.g. ERC20/ERC721/ERC1155)
   3. Besides `MagicSpend`, only allows external calls to a single allowed contract signed over by user
      1. Also can only use a single special selector defined by `IPermissionCallable`
   4. Does not allow spending other tokens (e.g. ERC20/ERC721/ERC1155)
   5. Does not allow approving or revoking permissions
   6. Validations are 100% compliant with ERC-4337
4. `PermissionCallable`
   1. Inherits `IPermissionCallable`
   2. Requires inheriting contracts to override supported-selectors function
   3. Adds default implementation for special selector which:
      1. Validates inner call selector is supported
      2. Accepts call arguments equivalent to calldata that could be sent as a valid call to the contract directly
      3. Can be overriden by inheriting contracts
