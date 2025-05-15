# SMART Redeemable Extension

This extension allows token holders to redeem (burn) their own tokens directly, effectively removing them from circulation.

## Overview

The redeemable extension provides a standard way for users to decrease the token supply by destroying tokens they own.

Key components include:

- **`_SMARTRedeemableLogic.sol`**: An internal abstract contract containing the core `redeem` function logic and the `Redeemed` event. It defines an abstract `_redeemable_executeBurn` function to delegate the actual burning mechanism and relies on standard `SMARTHooks` (`_beforeRedeem`, `_afterRedeem`).
- **`SMARTRedeemable.sol`**: The standard (non-upgradeable) implementation. It inherits `_SMARTRedeemableLogic` and `Context`. It implements `_redeemable_executeBurn` by calling the base `_burn` function (expected from an inherited `ERC20Burnable` or similar) and provides virtual overrides for `_beforeRedeem` and `_afterRedeem`.
- **`SMARTRedeemableUpgradeable.sol`**: The upgradeable implementation. It inherits `_SMARTRedeemableLogic`, `ContextUpgradeable`, and `Initializable`. It implements `_redeemable_executeBurn` similarly using `_burn` (expected from `ERC20Upgradeable`) and provides virtual hook overrides. Includes an initializer `__SMARTRedeemable_init`.

## Features

- **Self-Redemption**: Allows any token holder to call the `redeem(amount)` function to burn their own tokens.
- **Hook Integration**: Calls `_beforeRedeem` before and `_afterRedeem` after the burn operation, allowing for custom logic integration (e.g., checking conditions, interacting with external systems, updating off-chain records).
- **Event Emission**: Emits a `Redeemed` event upon successful redemption.
- **Standard & Upgradeable**: Provides both standard and upgradeable versions.

## Usage

To use this extension:

1. **Inherit Base Contracts**:
   - Inherit the core `SMART` or `SMARTUpgradeable` implementation.
   - Ensure the core implementation (or another inherited contract) provides an internal `_burn(address from, uint256 amount)` function (like `ERC20Burnable` or `ERC20Upgradeable`).
   - Inherit the corresponding redeemable implementation (`SMARTRedeemable` or `SMARTRedeemableUpgradeable`).
   - Inherit necessary base contracts (e.g., `ERC20`/`ERC20Upgradeable`).
2. **Implement Constructor/Initializer**:
   - **Standard (`SMARTRedeemable`)**: Call parent constructors in the final contract's `constructor`.
   - **Upgradeable (`SMARTRedeemableUpgradeable`)**: In the final contract's `initialize` function, call initializers for parent contracts (e.g., `__ERC20_init`, `__SMART_init`) and then call `__SMARTRedeemable_init()`.
3. **(Optional) Override Hooks**: If custom logic is needed before or after redemption, override the virtual `_beforeRedeem` and/or `_afterRedeem` functions in your final contract.

## Authorization

This extension does **not** implement specific authorization roles itself. The `redeem` function is public and intended to be called by any token holder. Authorization or eligibility logic can be added by overriding the `_beforeRedeem` hook.

## Security Considerations

- **Burn Mechanism**: Ensure the underlying `_burn` function provided by the base ERC20 implementation behaves correctly and securely.
- **Hook Logic**: If overriding `_beforeRedeem` or `_afterRedeem`, ensure the custom logic is secure and does not introduce vulnerabilities (e.g., reentrancy if interacting with external contracts).
- **Availability**: Ensure that the conditions possibly checked in `_beforeRedeem` do not unintentionally block legitimate redemptions permanently.
- **Interaction with Freezing**: Note that the standard `redeem` function will likely fail if the caller's address is frozen or if they try to redeem more than their _unfrozen_ balance when the Custodian extension is used, due to the checks in the Custodian's `_beforeRedeem` hook.
