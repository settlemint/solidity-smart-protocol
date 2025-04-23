# Custodian Extension

This extension provides custodial controls over token balances and transfers, typically managed by an authorized role (e.g., the token owner or a designated custodian). Key features include:

* **Address Freezing:** Freeze or unfreeze entire addresses, preventing any standard transfers to or from them.
* **Partial Token Freezing:** Freeze or unfreeze a specific *amount* of tokens held by an address, restricting only that portion from standard transfers.
* **Forced Transfers:** Allow an authorized role to forcefully transfer tokens *from* any address (even frozen ones or using frozen tokens) *to* a non-frozen address.
* **Address Recovery:** Facilitate the recovery of assets from a compromised or lost wallet to a new wallet, provided both wallets are associated with a verified on-chain identity via the `IdentityRegistry`. This process transfers the full token balance, frozen status, and any partially frozen token amounts.
* **Transfer Controls:** Integrates with standard token operations (`mint`, `transfer`, `burn`, `redeem`) to enforce the freezing rules. For example, minting to frozen addresses is blocked, and standard transfers require sufficient *unfrozen* balance. Burning may automatically unfreeze tokens if necessary.

## Usage

* Token needs REGISTRAR_ROLE on Identity Registry
