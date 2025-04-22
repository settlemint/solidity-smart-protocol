# SMART Protocol Changelog

## Changes from ERC-3643

- Token stores required claim topics and initial modules in the contract, allowing re-use of identity registry and compliance contract
- Token is more modular following the OpenZeppelin modular pattern
- Only modular compliance rules, but you can also choose to just create one compliance contract without the modules at all
- Token doesn't need to be bound to compliance contract, added _token parameter to all functions
- Removed the need to a separate claims topics registry, since we don't use it anymore
- Token will be passed in isVerified function to check if the identity has all the necessary claim topics
- Simplified the identity factory using proxy 1967 pattern.
- SMARTRedeemable extension for self-burning tokens

## TODO

- Integrate OpenZeppelin AccessControl
  - Also check that identityRegistry has access to the storage and the issuers registry

## Open questions?

- Should modules be upgradeable?
- Right now SMARTBurnable doesn't extend ERC20Burnable, because it follows ERC3643, which only has a burn(user, amount) function which is guarded by the owner. While ERC20Burnable has a burn(amount) and burnFrom(user, amount) function. This means right now a user can't burn their own tokens, which we might need for Redeem? 
  - Do we deviate from ERC3643 and follow ERC20Burnable? or do we implement a ERC20Redeemable extension?
