# Tests Overview

## Full Invariant List

1. `CoinbaseSmartWallet`
   1. Only transaction path impacted is when `PermissionManager` is used as owner
   2. Existing transaction paths work exactly the same
      1. Can transact with other owners
      2. Can remove PermissionManager as an owner
      3. Can add and remove other owners
      4. Can upgrade the contract
2. `PermissionManager`
   1. Can only validate signatures for user operations
   2. Cannot update Smart Wallet owners
   3. Cannot upgrade Smart Wallet implementation
   4. Cannot make self-calls as a precaution
   5. Only validates user operations when
      1. Manager is not paused
      2. UserOp is signed by Permission signer ("session key")
      3. UserOp is signed by cosigner or pending cosigner
      4. UserOp paymaster is enabled by Manager
      5. UserOp and Permission are validated together by Permission Contract
      6. Permission Contract is enabled by Manager
      7. Permission account matches UserOp sender
      8. Permission chain matches current chain
      9. Permission verifyingContract is Manager
      10. Permission has not expired
      11. Permission is approved via storage or signature by a different owner on smart wallet
      12. Permission has not been revoked
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
4. `PermissionCallable`
   1. Inherits `IPermissionCallable`
   2. Requires inheriting contracts to override supported-selectors function
   3. Adds implementation for special selector which validates inner call selector is supported
   4. Special selector can be overriden
