# Withdraw from Spend Permissions

The first time using a recurring allowance, the spender needs to pack an additional `permit` call before withdrawing to validate and store the approval. After a recurring allowance has been approved, the spender only needs to call `withdraw` to transfer tokens from the Smart Wallet.

```mermaid
sequenceDiagram
    autonumber
    participant S as Spender
    participant M as Spend Permissions
    participant A as Smart Wallet
    participant ERC20

    opt
        S->>M: permit(spendPermission, signature)
    end
    Note over M: validate signature and store approval
    S->>M: withdraw(spendPermission, value)
    Note over M: validate recurring allowance authorized <br> and withdraw value within allowance
    M->>A: execute(target, value, data)
    Note over M,A: transfer tokens
    alt token is address(e)
        A->>S: call{value}()
        Note over A,S: transfer native token to spender
    else else is ERC20 contract
        A->>ERC20: transfer(spender, value)
        Note over A,ERC20: transfer ERC20 to spender
    end
```
