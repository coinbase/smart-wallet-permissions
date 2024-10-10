# Batch Signing

Apps may request to spend many different tokens from a user. If users have to sign each spend permission individually, this could be a minor nuissance at minimum, or make certain applications wholly impractical at maximum. Our goal with a Batch Signing feature is to enable users to only have to sign once for an arbitrary number of spend permissions.

## Data Structure

There are a three general approaches to allow us to do this:

1. Array-ify a subset of fields within `RecurringAllowance` (e.g. `token` and `allowance`) and keep the other fields shared for the batch
1. Allow an array of `RecurringAllowance` structs and sign over the hash of the array.
1. Allow an array of `RecurringAllowance` structs and sign over a Merkle root where the structs are leaves in a Merkle Tree.

The first option is most similar to [Permit2](https://github.com/Uniswap/permit2/blob/main/src/interfaces/ISignatureTransfer.sol#L51-L58) and is straightforward. The main downside is that this locks us into grouping by fields not included in the array which we currently lack sufficient product confidence to make a decision of what should be forced to be consistent across all allowances.

The second option allows us to be flexible with batching with variation across any fields. The main downside is that we may be sending a lot of calldata depending on how many allowances are batched together. Additionally, if we do end up sharing the same values for many fields, we are wasting calldata on this duplication.

The third option allows us to maintain flexibility with better gas scaling. The array of recurring allowances are hashed, sorted, and then iteratively hashed up forming a Merkle Tree. The root of this tree is what users actually sign with their Smart Wallet and can be used to approve any recurring allowance within in. To submit a `permit` to validate the signature and apply the approval, we just need to provide the `RecurringAllowance` struct and a `bytes32[]` path of intermediate hashes to reconstruct the root. Note that the number of elements in this array scaled `0(log(n))` which is more favorable than the previous option and also each element only takes up one word of calldata.

![merkleTree](https://github.com/user-attachments/assets/9b2cf44d-8a67-430b-a5a9-4ed78dd7a973)

There are three kinds of nodes in our Merkle Tree computed as:

1. Leaf nodes: Hashes of individual `RecurringAllowance` structs
1. Intermediate nodes: Hashes of concatenating two sibling nodes (children of the same parent)
1. Root node: Final intermediate node where there are no more siblings to hash with

## Offchain Hash Construction

Given an array of recurring allowances, we need to compute a Merkle root for the user to sign.

We start by hashing our `RecurringAllowance` structs to form our leaf nodes with: `keccak256(abi.encode(recurringAllowance, chainId, verifyingContract))`. With an array of leaf nodes of shape `bytes32[]`, we sort this array in increasing order. Iteratively, we hash pairs of sibling nodes via `keccak256(abi.encode(lowerSibling, higherSibling))` to build up more layers of the tree with each layer being half the width of the previous layer. Note that between a pair of sibling nodes, the order within the hash computation **does matter**. We consistently order our hashing by comparing the values of the two siblings and make sure the ordering is lower then higher sibling. We continue iteratively hashing until we reach one final root node.

Our [offchain implementation](../node/utils/merkleTree.ts) is a fork of [openzeppelin/merkle-tree](https://github.com/OpenZeppelin/merkle-tree) rewritten with `viem` and focused on their "simple" Merkle Tree implementation without [Second Preimage Attack](https://flawed.net.nz/2018/02/21/attacking-merkle-trees-with-a-second-preimage-attack/) mitigation.

## Onchain Signature Verification

After the user signs the batch of recurring allowances, we determine the individual Merkle proofs (type `bytes32[]`) for each and add it to a `SignedPermission` struct that contains the recurring allowance and user signature. Apps receive an array of permission contexts, one per recurring allowance, that is computed as a simple ABI-encoding of `SignedPermission`.

When submitting a request to `withdraw`, apps can provide this context as-is and we will attempt to verify the permit and then withdraw against the allowance. Verifying a permit starts with recomputing the Merkle root by converting the `RecurringAllowance` to a leaf node via `keccak256(abi.encode(recurringAllowance, chainId, verifyingContract))` and then iterating over the `bytes32[] proof` array by iteratively chaining hashes. We use [OpenZeppelin's `MerkleProof` library](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol#L57-L63) to implement this iteration and root generation.

Note that the iterative hashing of a proof also applies the same commutative hashing process where the lower sibling is always first in the concatenation for parity with offchain. We use [OpenZeppelin's `Hashes` library](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/Hashes.sol) to implement this commutative hashing.

After computing a Merkle root, we then check the provided `SignedPermission.signature` is valid by calling the recurring allowance's account with EIP-1271 `isValidSignature`. If the leaf node or Merkle proof are invalid, the computed root hash would change and not validate for the provided signature.

## Future Composability

Note that the inclusion of `chainId` and `verifyingContract` in the leaf hash for a recurring allowance is intentional in that it keeps the root hash agnostic to chain and contract choice. This allows us to perform cross-chain and cross-contract batch signatures while still preserving cross-chain and cross-contract replay protection.

We also have open-ended flexibility to compose other kinds of leaf nodes, for example a future `NftAllowance` struct, within the same batch signing event as Spend Permissions V1. This composability is powerful for future product developments, but deserves security scrutiny for potentially being too flexible.

### Examples

### Single Allowance

If an app only needs to request a single recurring allowance, the leaf node is also the root node. This means the `bytes32[]` Merkle proof will be an empty array and no iterative hashing is performed. This effectively means that non-batched signatures function exactly the same as if this batching mechanism didn't exist. This provides us an easy way to implement our V1 on the offchain side without concerning ourselves with this more advanced Merkle Tree construction.

### Multiple Allownaces

Below is pseudo-code for offchain preparation of the Merkle Tree, root, signature, and individual contexts returned back to the app.

```tsx
// receive spend permissions RPC request
const request;

// prepare recurring allowance structs from requests
const recurringAllowance0 = getRecurringAllowance(request[0]);
const recurringAllowance1 = getRecurringAllowance(request[1]);

// hash recurring allowances to create leaves
const leaf0 = hashRecurringAllowance(recurringAllowance0);
const leaf1 = hashRecurringAllowance(recurringAllowance1);

// form merkle tree with leaves
const merkleTree = makeMerkleTree([leaf0, leaf1]);

// get individual proofs for each leaf
const proof0 = getProof(merkleTree, leaf0);
const proof1 = getProof(merkleTree, leaf1);

// get the root of the tree and sign
const root = getRoot(merkleTree);
const signature = await signHash(root);

// prepare contexts from recurring allowance, merkle proof, and signature
const context0 = prepareContext({
  recurringAllowance: recurringAllowance0,
  proof: proof0,
  signature
});
const context1 = prepareContext(
  recurringAllowance: recurringAllowance1,
  proof: proof1,
  signature
);

// return requests with context
return [
  { ...request[0], context: context0 },
  { ...request[1], context: context1 },
];
```
