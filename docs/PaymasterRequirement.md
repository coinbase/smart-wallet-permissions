# Paymaster Requirement

- it is critical that token expenditure be accounted for onchain and for this accounting to be 100% accurate
- when a paymaster is not used, i.e. the gas funds come directly from the user's account, there is risk that the accounting logic does not keep up
- this is because our recurring allowance accounting relies on successfully calling back into the permission contract which relies on successful execution of the user operation
- if a paymaster is not used and user operation fails for any reason (including exceeding the allowance) then the gas is still paid by the user to the bundler, but this is not tracked
- without mitigation, this opens a attack vector where an app can spend the user's entire native token balance on failing user operations
- the mitigation is simply to require apps to pay for the gas costs of permissioned user operations to align incentives
- if the app does not submit successful user operations, it is the app that bears that cost
- this does not force apps to pay for all user operations though, just to front the initial promise to the bundler
- if an app would like users to pay for their gas, they can prepare a call to refund themselves in the same user operation
- should many apps request and leverage this capability, we may consider adding a paved road for this pattern of refunding the sponsoring app

- note that this fundamental issue of accounting for users native token expenditure on gas for failing user operations also applies for when MagicSpend is used as a paymaster
- in the MagicSpend case, users assets are still fronting the bundler's gas payment so we also exclude MagicSpend as a valid paymaster
- note that this does not prevent apps from using MagicSpend withdraws within a user operation or using part of these withdrawn funds to refund itself, just for initial bundler payment
