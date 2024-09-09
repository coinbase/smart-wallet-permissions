# Cosigner

- as much as possible, we want the trust and security of our system to be onchain
- however, there are some security measures that can only be taken offchain with current technology
- to provide the best of both worlds, we require that all permissioned user operations must be signed by a cosigner that will run checks offchain before signing
- this check is enforced through the PermissionManager
- this compliments our existing security measures built into PermissionManager (pausable, enabled permission contracts, enabled paymasters) by providing a path for granular application of other flexible contraints on a per user operation basis
- the first set of responsibilities for the cosigner is to support blocklists for specific apps, signers, and external contracts that are compromised or intend to harm users

- note that any blocking at the cosigner level only applies to permissioned user operations and does not impact the normal transaction flow through keys.coinbase.com
- also note that the cosigner cannot submit permissioned user operations on its own and a signature from an app to initiate is still required

additional responsibility for permission contract V1:

- our first permission contract also requires additional offchain validation assistance to uphold the invariant that it can only be used to spend native token
- in absence of cosigning, it is actually possible for a permissioned user operation to spend contract tokens (ERC20, ERC721, ERC1155) if these tokens extend an allowance to an allowed external contract for permissions
- this situation requires two preconditions (setup in either order)
  1. the user approved a permission to call contract A
  2. the user approved an allowance for contract A to spend token B
- now when the app submits a user operation for the user to call contract A, it is possible for this call to spend users token B
- especially with infinite approvals being common, this is a potentially dangerous path to enable for a permission that claims to only support spending native token so we will not be cosigning these user operations to prevent this
- we will detect these cases by simulating every user operation, parsing the emitted logs, and look for any log that matched the ERC20/ERC721/ERC1155 transfer logs where the `from` argument is the user's address (`userOp.sender`)

- note that this simulation logic also prevents another path for apps to attempt to spend tokens where the external contract is itself a token
- this could be possible if the token contract implements our defined `permissionedCall` selector and is approved as an allowed contract by the user
- we can prevent potentially malicious calls to these contracts by preventing any user operation with outboung approval events in addition to the same out-bound transfer logs limitation
- developers that want to use token contracts within permissioned user operations are encouraged to wait until we add proper onchain accounting for these cases
- ERC20 support is one of our top priorities for the next iteration coming in Q4 2024
