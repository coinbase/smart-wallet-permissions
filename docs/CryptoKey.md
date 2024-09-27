# CryptoKey

Now that apps are able to sign user operations on behalf of users, a few patterns of key custody emerge:

1. Self-custodial keys bound to apps
2. Partial-custodial keys bound to apps
3. Custodial keys owned by apps

All custodial patterns have different tradeoff sweet spots, but for now we are most interested in exploring option 1 first.

The most common implementation that may come to mind are [Passkeys](https://www.passkeys.com/). While passkeys enable self-custody in a secure and simple manner, their additional friction to sign via a second user verification (e.g. biometric scan) can be cumbersome. For our goals of reaching UX that is on par or superior than any existing application, this is too much friction.

In pursuit of something simpler, we discovered [CryptoKey](https://developer.mozilla.org/en-US/docs/Web/API/CryptoKey), a standard web library for generating key pairs and signing messages. In our research thus far, we believe CryptoKeys provide the simplest way for apps to offer self-custodial Session Keys without compromising on usability or security. You can think of it like a slightly less secure Passkey, but without the additional user confirmation burden so we can make signing invisible.

CryptoKey offers a handful of utilities, but there are four we need to build Session Keys:

1. [Asymmetric signatures (ECDSA)](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/sign#ecdsa)
2. [Onchain-compatible curve (P-256)](https://developer.mozilla.org/en-US/docs/Web/API/EcKeyGenParams#namedcurve)
3. [Same-origin storage (IndexedDB)](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API/Basic_Terminology)
4. [Non-extractable](https://developer.mozilla.org/en-US/docs/Web/API/CryptoKey/extractable)

To make this approach even possible, we need the ability to sign arbitrary hashes whose signatures can be verified onchain. Accessing the same signature algorithm (ECDSA) and "P-256" curve (secp256r1) as Passkeys lets us reuse the same signature verification used natively by Coinbase Smart Wallet.

To make this approach secure, we need the ability to guarantee that keys cannot be accessed by any party other than the app (same-origin storage) or ever leave the device (non-extractable). These two properties actually make CryptoKeys more secure than patterns that transmit secrets over a network (e.g. cookies), which we all rely on for most web applications.

Note that CryptoKey is a less opinionated library than WebAuthn, which means we can actually sign raw hashes compared to WebAuthn's custom object that packs additional data. Because we would like to reuse existing onchain verifiers like [WebAuthn.sol](https://github.com/base-org/webauthn-sol/blob/main/src/WebAuthn.sol), we actually wrap all hashes within a hardcoded WebAuthn object for compatibility.

Also note that IndexedDB, our storage mechanism for CryptoKeys, is not the most intuitive to use. We are actively working on an SDK that makes it easier to generate, read, and sign with CryptoKeys for onchain-native use cases.
