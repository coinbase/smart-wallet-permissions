# Smart Wallet Permissions Docs

> :information_source: These contracts are unaudited. Please use at your own risk.

With [ERC-7715](./ERC-7715.md), users can grant permissions to apps to submit transactions on their behalf. These docs are meant to walk you through the key design decisions and mechanisms that chose to enable this feature at the contract layer. Reading all linked resources is encouraged to get the full depth of design intuition.

## Design Overview

### 1. ERC-4337 alignment

Our first iteration chose to lean into the patterns defined by [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) for actually executing onchain. This allowed us to share infrastructure Coinbase and many other teams have invested in for Bundlers and Paymasters. It also absolved us of redesigning a solution for problems that the Entrypoint already solves like DoS protection via separation of validation and execution phases and modularizing gas payment.

### 2. Optional addition to Coinbase Smart Wallet V1

While implementing this feature as a new V2 wallet implementation was tempting, we decided to leverage the modular owner system from [Smart Wallet V1](https://github.com/coinbase/smart-wallet) and avoid a hard upgrade. This helped reduce our launch timeline and also reduced the risk of introducing this substantially different account authentication paradigm.

## End-to-end Journey

### 1. App requests permissions from user (offchain)

View a sample sequence diagram [here](./diagrams/offchain/grantPermissions.md) and Smart Wallet's supported capabilities [here](./ERC-7715.md).

### 2. App prepares and sends calls (offchain)

View a sample sequence diagram [here](./diagrams/offchain/prepareCalls+sendCalls.md).

### 3. Bundler executes User Operation (onchain)

View a sample sequence diagram [here](./diagrams/onchain/withdraw.md).
