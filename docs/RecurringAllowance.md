# Recurring Allowance

- if permissions are successful, the users wallet is less intrusive in the daily user experience
- taking a look at existing approval mechanisms from common token standards, we see an antipattern of over-permissive infinite allowances
- apps don't want to have to ask the user every single time they want to spend tokens so instead they ask for trust
- users aren't really given a choice if they want to use the product, so they comply
- with permissions, we're able to redefine a new standard for allowances with a recurring mechanism
- recurring allowances allow an app to request to spend user assets on a recurring time period (e.g. 1 ETH / month)
- as apps spend user assets through using this permission, the recurring allowance automatically limits for the current period
- once enough time passes to enter the next cycle, the allowance usage is reset to zero and the app can spend again

- this design allows users and apps to have reduced friction in approving asset use, while still giving the user control to manage risk and keep asset allowance small upfront
- this design also follows intuitively from existing recurring models like subscriptions, automated trading strategies, and payroll

- we believe by keeping allowance usage onchain, we're able to create a safer and trust minimized permission system

how do allowances get used?

- within a batch of calls, a call from the account back to the permission contract is expected to set the proper amount of new expenditure
- if the allowance is exceeded, the call should revert and thanks to atomicity, revert the entire call batch that is attempting to spend assets
- it is up to implementing permission contracts to expose the external method to leverage this utility

how does the accounting work?

- a recurring allowance requires a start time, cycle period, and allowance per cycle
- these values are initialized when a permission is first added to approval storage by the permission manager and are immutable
- these values set a deterministic schedule infinitely into the future for when allowances reset to zero for the next allowance cycle
- [diagram]
