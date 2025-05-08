# SMART Burnable Extension

This extension provides functionality to burn (destroy) SMART tokens. It separates the core burning logic from authorization, allowing flexible access control implementations.

Note: This is following the ERC3643 standard so only the operator can burn tokens. So we are not extending ERC20Burnable.

## Overview

The burnable extension consists of several key components:

- **`_SMARTBurnableLogic.sol`**: Contains the core internal logic for burning tokens, including the `burn` and `batchBurn` functions and the `BurnCompleted` event. It defines abstract hooks for authorization (`_authorizeBurn`) and execution (`_burnable_executeBurn`).
- **`SMARTBurnable.sol`**: The standard (non-upgradeable) implementation. It inherits `_SMARTBurnableLogic` and implements `_burnable_executeBurn` by calling the `_burn` function of a standard ERC20 contract.
- **`SMARTBurnableUpgradeable.sol`**: The upgradeable implementation. It inherits `_SMARTBurnableLogic`, is `Initializable`, and implements `_burnable_executeBurn` by calling the `_burn` function of an ERC20Upgradeable contract.
- **`_SMARTBurnableAuthorizationHooks.sol`**: Defines the abstract `_authorizeBurn` hook used by `_SMARTBurnableLogic`.
- **`SMARTBurnableAccessControlAuthorization.sol`**: An example authorization implementation using OpenZeppelin's AccessControl. It defines a `BURNER_ROLE` and implements `_authorizeBurn` to check if the caller has this role.

## Features

- **Operator Burn Tokens**: Allows authorized addresses (operators/admins) to burn tokens from any user's address. The `burn(address userAddress, uint256 amount)` function signature aligns with the intent of ERC3643's `operatorBurn`.
- **Batch Operator Burn**: Allows authorized addresses to burn tokens from multiple addresses in a single transaction.
- **Authorization Hook**: Decouples burning logic from authorization via the `_authorizeBurn` hook.
- **Execution Hook**: Decouples the extension from the specific ERC20 implementation via the `_burnable_executeBurn` hook.
- **Events**: Emits a `BurnCompleted` event upon successful burning.
- **Standard & Upgradeable**: Provides both standard and upgradeable versions.

## Usage

To use this extension:

1. **Inherit the Base Extension**: Choose either `SMARTBurnable` (for standard contracts) or `SMARTBurnableUpgradeable` (for upgradeable contracts) and inherit it in your main SMART token contract.
2. **Inherit Base Token**: Ensure your main contract also inherits the corresponding ERC20 implementation (e.g., `ERC20PresetMinterPauser` or `ERC20PresetMinterPauserUpgradeable`). This provides the necessary `_burn` function.
3. **Inherit Authorization**: Inherit an authorization contract that implements `_SMARTBurnableAuthorizationHooks` (e.g., `SMARTBurnableAccessControlAuthorization`) or create your own.
4. **Initialization (Upgradeable Only)**: If using the upgradeable version, call `__SMARTBurnable_init()` within your main contract's initializer.
5. **Grant Roles (AccessControl Example)**: If using `SMARTBurnableAccessControlAuthorization`, grant the `BURNER_ROLE` to addresses that should be allowed to perform operator burns (typically admin or specific operator roles).

## Authorization

The `_authorizeBurn` hook allows for custom authorization logic. The provided `SMARTBurnableAccessControlAuthorization` requires the caller to have the `BURNER_ROLE`. This role should be granted only to trusted administrators or operators responsible for managing the token supply, aligning with the ERC3643 standard's concept of operator-initiated actions.

Alternative authorization strategies could include:

- Allowing only the token contract owner (`Ownable`).
- Allowing *any* token holder to burn *only their own* tokens (requires modifying the `_authorizeBurn` logic and potentially the `burn` function signature if self-burning is the primary goal).
- Implementing time-locks or multi-sig requirements for burn operations.

## Security Considerations

- **Authorization**: Carefully define who receives the `BURNER_ROLE` (or equivalent permission). Granting operator burn capabilities widely can lead to accidental or malicious token destruction.
- **Access Control**: Ensure the AccessControl roles (or other authorization mechanisms) are managed securely, especially the admin role that can grant/revoke the `BURNER_ROLE`.
