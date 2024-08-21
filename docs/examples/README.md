## Get started

> **Note**: These contracts are unaudited, use at your own risk.

### 0. Integrate Coinbase Smart Wallet into your app.

The [smartwallet.dev](https://www.smartwallet.dev/why) docs are recommended.

### 1. Add support for permissioned user operations to call your smart contract.

```solidity
import {PermissionCallable} from "smart-wallet-permissions/src/utils/PermissionCallable.sol";

contract Contract is PermissionCallable {
    // define which function selectors are callable by permissioned userOps
    function supportsPermissionedCallSelector(bytes4 selector) public pure override returns (bool) {
        return selector == Contract.foo.selector;
    }
    // callable by permissioned userOps
    function foo() external;
    // not callable by permissioned userOps
    function bar() external;
}
```

### 2. Reach out for access to our Private Alpha on Base Sepolia.

Join our [Telegram group](https://t.me/+r3nLFnTj6spkNzdh) and post a message describing your project and intended use of Smart Wallet Permissions.
