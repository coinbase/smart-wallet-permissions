# Recurring Allowance

## Onchain accounting

Tracking asset expenditure accurately is important for enforcing user-approved limits. Given the fragility and complications with doing this accounting offchain and the severity of inaccuracies, we designed for fully onchain accounting. Onchain accounting enables us to have higher confidence in its reliability and keep our system trust-minimized.

To do accounting onchain, we need to design a storage layout and make sure to update it every time assets are spent. For the limited scope of native tokens, we can detect the amount spent by looping over calls in the batch and accumulate `msg.value` on each call. At the end of the call batch, we expect to make an external call to a specific function designed to save the new spend and enforce the user-approved limits. If the enforcement reverts, the entire call batch is reverted too thanks to Smart Wallet's atomicity guarantee.

### Recurring accounting

Now that Session Keys replace a pop-up window every transaction with a pop-up window for approving every permission, the frequency of permission requests is the new baseline annoyance for wallet UX. How can we minimize this intrusion?

Taking a look at the existing approval for common token standards, we see unfortunately see an antipattern of over-permissive infinite allowances. Apps also don't want to have to ask the user every single time they want to spend tokens so instead they ask for a high amount of trust. Users aren't really given a choice if they want to use the product, so they comply and extend that trust. Unfortunately, this trust has led to countless drainer events which we would like to prevent with Session Keys.

Our solution is to create recurring allowances that allow an app to request to spend user assets on a recurring basis (e.g. 1 ETH / month). As apps spend user assets through using this permission, the recurring logic automatically increments and enforces the allowance for the current cycle. Once enough time passes to enter the next cycle, the allowance usage is reset to zero and the app can keep spending up to the same allowance.

This design allows users and apps to have reduced friction in approving asset use, while still giving the user control to manage risk and keep asset allowance small upfront. This design is also intuitive for users and can easily support recurring models like subscriptions, automated trading strategies, and payroll.

A recurring allowance is defined by 3 values:

1. start time
2. cycle period
3. allowance per cycle

The start time and cycle period set a deterministic schedule infinitely into the future for when allowances reset to zero for the next cycle.

Here are the first few cycles for a recurring allowance:

1. `[start, start + period - 1]`
1. `[start + period, start + 2 * period - 1]`
1. `[start + 2 * period, start + 3 * period - 1]`

Which follows the general form for the `n`th cycle's time range: `[start + (n - 1) * period, start + n * period - 1]` with first `n = 1`.

When a new spend of a recurring allowance is attempted, the contract first determines what the current cycle's usage is. If the current time falls within the cycle of last stored use, we simply check if this new usage will exceed the allowance. If the current time exceeds the cycle of last stored use, that means we are in a new cycle and should reset the allowance to zero and then add our new attempted spend. By leveraging a single storage slot, we are able to have a gas cost that does not scale with usage, keeping it efficient.
