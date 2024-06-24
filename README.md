# Smart Wallet Periphery

A set of contracts on the periphery to extend the utility of Smart Wallets.

Session Keys are the first flagship feature, but this repository will continue to grow with other use cases over time.

## Session Keys

Currently, all signature and transaction requests on Smart Wallet need to go through a new pop-up window on "keys.coinbase.com" to be signed by a user’s passkey. We have received feedback from developers and users that this process can feel slow, frictionful, and disjoint from the app experience (especially on mobile, which represents 65% of smart wallet users). 

"Session keys" are a method for granting ephemeral permissions to additional Ethereum addresses and passkeys that enable apps to prompt signatures without going through our pop-up window. By doing so, they can create signature-less experiences and run background processes after getting user approval.

### Use Cases
- Sign and transact completely in-app
    - Mint NFTs with a passkey biometric scan
    - Take in-game actions with invisible background signing
- Sign and transact in the background while user is off-app
    - Set limit orders to buy/sell assets that get executed as soon as conditions trigger
    - Sign up for a subscription that transfers assets on a set schedule

### Goals
- Enable apps to easily request scoped permissions from smart wallet users
- Enable apps to easily submit transactions using these permissions
- Provide built-in protections for users’ assets and security-related state 
- Enable all existing smart wallet users to use this functionality without an upgrade to the core `CoinbaseSmartWallet` implementation