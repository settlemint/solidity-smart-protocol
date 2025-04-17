# SMART Protocol Changelog

## Changes from ERC-3643

- Token stores required claim topics and initial modules in the contract, allowing re-use of identity registry and compliance contract
- Token is more modular following the OpenZeppelin modular pattern
- Only modular compliance rules, but you can also choose to just create one compliance contract without the modules at all
- Token doesn't need to be bound to compliance contract, added _token parameter to all functions
- Removed the need to a separate claims topics registry, since we don't use it anymore
- Token will be passed in isVerified function to check if the identity has all the necessary claim topics
- Simplified the identity factory using proxy 1967 pattern.

## TODO

- Integrate MetaTx
- Should extensions be upgradable?
- Integrate OpenZeppelin AccessControl
  - Also check that identityRegistry has access to the storage and the issuers registry

## Ideas

- Can identity verification become a Compliance module?