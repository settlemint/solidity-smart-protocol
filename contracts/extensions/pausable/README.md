# SMART Pausable Extension

This extension adds standard pausable functionality to SMART tokens, allowing authorized roles to temporarily halt key operations like transfers, mints, and burns.

## Overview

The pausable extension provides a mechanism to stop token movements, often used during upgrades, emergencies, or maintenance periods.

Key components include:

-   **`_SMARTPausableLogic.sol`**: An internal abstract contract holding the `_paused` boolean state, the `pause`/`unpause` functions (guarded by an authorization hook), the `Paused`/`Unpaused` events, and the `whenNotPaused`/`whenPaused` modifiers.
-   **`_SMARTPausableAuthorizationHooks.sol`**: Defines the abstract `_authorizePause` hook called by `_SMARTPausableLogic`.
-   **`SMARTPausableAccessControlAuthorization.sol`**: An example authorization implementation using OpenZeppelin's AccessControl. It defines the `PAUSER_ROLE` and implements the `_authorizePause` hook.
-   **`SMARTPausableErrors.sol`**: Defines custom errors `TokenPaused` and `ExpectedPause` used by the modifiers.
-   **`SMARTPausable.sol`**: The standard (non-upgradeable) implementation. It inherits `_SMARTPausableLogic` and overrides the base `ERC20._update` function, applying the `whenNotPaused` modifier to it.
-   **`SMARTPausableUpgradeable.sol`**: The upgradeable implementation. It inherits `_SMARTPausableLogic`, `Initializable`, and overrides the base `ERC20Upgradeable._update` function, applying the `whenNotPaused` modifier. Includes an empty initializer `__SMARTPausable_init`.

## Features

-   **Pause/Unpause Control**: Allows authorized addresses (`PAUSER_ROLE`) to pause and unpause the contract.
-   **Transfer Halt**: When paused, standard transfers, mints, and burns are prevented via the `whenNotPaused` modifier applied to the core `_update` function.
-   **Events**: Emits `Paused` and `Unpaused` events.
-   **Standard & Upgradeable**: Provides both standard and upgradeable versions.

## Usage

To use this extension:

1.  **Inherit Base Contracts**:
    *   Inherit the core `SMART` or `SMARTUpgradeable` implementation.
    *   Inherit the corresponding pausable implementation (`SMARTPausable` or `SMARTPausableUpgradeable`).
    *   Inherit an authorization contract implementing `_SMARTPausableAuthorizationHooks` (e.g., `SMARTPausableAccessControlAuthorization`).
    *   Inherit necessary base contracts (e.g., `ERC20`/`ERC20Upgradeable`, `AccessControlUpgradeable`/`OwnableUpgradeable` if applicable).
2.  **Implement Constructor/Initializer**:
    *   **Standard (`SMARTPausable`)**: In the final contract's `constructor`, call constructors of parent contracts. Grant the initial `PAUSER_ROLE`.
    *   **Upgradeable (`SMARTPausableUpgradeable`)**: In the final contract's `initialize` function, call initializers for parent contracts (e.g., `__ERC20_init`, `__AccessControl_init`, `__SMART_init`) and then call `__SMARTPausable_init()`. Grant the initial `PAUSER_ROLE`.
3.  **Implement Abstract Functions**: Ensure `_msgSender()` and `hasRole()` from the authorization base are implemented (usually handled by inheriting standard OZ AccessControl).

## Authorization

The `SMARTPausableAccessControlAuthorization` contract provides a role-based implementation:

-   `PAUSER_ROLE`: Can call `pause()` and `unpause()`.

This role must be granted securely.

## Security Considerations

-   **Role Management**: The `PAUSER_ROLE` grants the ability to halt token operations. Centralization risk should be considered. Use multi-sig or DAO control for this role in production.
-   **Liveness**: Ensure there is a reliable mechanism to unpause the contract if needed. Losing access to the `PAUSER_ROLE` could permanently halt the token.
-   **Interaction with Forced Actions**: Note that functions like `forcedTransfer` (from the Custodian extension) typically bypass the `whenNotPaused` check by design (using the `__isForcedUpdate` flag). Pausing stops standard user/contract interactions, not necessarily all administrative actions.


