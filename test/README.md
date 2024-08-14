# Tests Overview

## Full Invariant List

1. `CoinbaseSmartWallet`
   1. Only transaction path impacted is when `PermissionManager` is used as owner
   2. Existing transaction paths work exactly the same
   3. Can transact with other owners
   4. Can remove PermissionManager as an owner
   5. Can add and remove other owners
   6. Can upgrade the contract
2. `PermissionManager`
   1. Can only validate signatures for user operations
   2. Cannot update Smart Wallet owners
   3. Cannot upgrade Smart Wallet implementation
   4. Cannot make self-calls as a precaution
   5. Only validates user operations when
   6. Manager is not paused
      1. UserOp is signed by Permission signer
      2. UserOp is signed by cosigner or pending cosigner
      3. UserOp Paymaster is enabled
      4. Permission account matches UserOp sender
      5. Permission chain matches current chain
      6. Permission verifyingContract is the current manager
      7. Permission has not expired
      8. Permission is approved via storage or signature by a different owner on smart wallet
      9. Permission has not been revoked
      10. Permission is validated by Permission Contract
      11. Permission Contract is enabled
3. `NativeTokenRollingSpendLimit`
   1. Only allows spending ETH up to a rolling limit
      1. Includes spending on external contract calls
      2. Includes spending on gas
      3. Does not allow sending ETH as direct transfer
      4. If a userOp spends X and also receives Y, the spend registered is X independent of what Y is
   2. Allows withdrawing from MagicSpend
      1. Withdraws are not "spending" because it is just moving assets from a users offchain account to this onchain account
      2. Supports direct withdraw or `withdrawGasExcess` incase used as a Paymaster
   3. Otherwise, only allows external calls to a single allowed contract using a single special selector
   4. Does not allow spending other tokens (ERC20/ERC721/ERC1155)
4. `PermissionCallable`
   1. Automatically adds required special selector to inheriting contracts
   2. Requires inheriting contracts to override supported-selectors function
   3. Special selector validates inner call selector is supported
   4. Special selector can be overriden
