## Get started

> **Note**: These contracts are unaudited, use at your own risk.

### 0. Integrate Coinbase Smart Wallet into your app.

The [smartwallet.dev](https://www.smartwallet.dev/why) docs are recommended.

### 1. Add support for permissioned user operations to call your smart contract.

If you do not yet have `forge` installed, first [install the foundry toolkit](https://book.getfoundry.sh/getting-started/installation).

```bash
forge install coinbase/smart-wallet-permissions
```

After installing this codebase as a dependency in your project, simply import and inherit `PermissionCallable` into your contract and override the `supportsPermissionedCallSelector` function to allow your functions to be called by permissioned userOps.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

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

### 2. Reach out for help in our Discord

Join our [Coinbase Developer Platform Discord](https://discord.com/invite/cdp/), join the `#smart-wallet` channel, and post a message describing your project and intended use of Smart Wallet Permissions if you encounter issues.
