# Core SMART Extension

This extension provides the fundamental building blocks and core logic for creating SMART tokens, integrating ERC20 functionality with identity verification and compliance checks.

## Overview

The core extension is the foundation upon which SMART tokens are built. It defines the essential state, functions, and events required for a token to manage identity, compliance, and standard ERC20 operations.

Key components include:

- **`_SMARTLogic.sol`**: An internal abstract contract containing the shared state variables (like `__identityRegistry`, `__compliance`, `__complianceModuleList`), core logic (validation, hook helpers like `_smart_beforeTransferLogic`), and events (like `TransferCompleted`, `ComplianceModuleAdded`). It also defines the internal `__SMART_init_unchained` function used for initialization.
- **`_SMARTAuthorizationHooks.sol`**: Defines abstract internal functions (`_authorizeUpdateTokenSettings`, `_authorizeMintToken`, etc.) that `_SMARTLogic` calls before executing permissioned actions. These hooks must be implemented by an authorization contract.
- **`SMARTAccessControlAuthorization.sol`**: An example authorization implementation using OpenZeppelin's AccessControl. It defines roles (`TOKEN_ADMIN_ROLE`, `COMPLIANCE_ADMIN_ROLE`, `VERIFICATION_ADMIN_ROLE`, `MINTER_ROLE`) and implements the hooks from `_SMARTAuthorizationHooks` to enforce role checks.
- **`SMART.sol`**: The standard (non-upgradeable) implementation contract. It inherits `ERC20`, `_SMARTLogic`, and `SMARTExtension`. It provides a constructor to initialize the state via `__SMART_init_unchained` and overrides ERC20 functions (`transfer`, `transferFrom`, `_update`) to integrate the SMART hooks.
- **`SMARTUpgradeable.sol`**: The upgradeable (UUPS) implementation contract. It inherits `ERC20Upgradeable`, `UUPSUpgradeable`, `_SMARTLogic`, and `SMARTExtensionUpgradeable`. It provides an internal initializer (`__SMARTUpgradeable_init`) that calls `__SMART_init_unchained` and overrides upgradeable ERC20 functions to integrate SMART hooks. It requires an additional access control mechanism (like `OwnableUpgradeable` or `AccessControlUpgradeable`) for managing upgrades via `_authorizeUpgrade`.

## Features

- **ERC20 Compliance**: Standard token functions (`transfer`, `approve`, `balanceOf`, etc.).
- **Identity Integration**: Connects to an `ISMARTIdentityRegistry` to verify recipients based on required claim topics before transfers and mints.
- **Compliance Integration**: Connects to an `ISMARTCompliance` contract and associated `ISMARTComplianceModule`s to enforce transfer rules and notify compliance systems.
- **Mutable Metadata**: Allows authorized roles to update token name, symbol, and on-chain ID post-deployment.
- **Modular Compliance**: Supports adding, removing, and updating parameters for compliance modules.
- **Verification Configuration**: Allows authorized roles to manage the identity registry address and required claim topics.
- **Authorization Hooks**: Decouples core logic from specific access control mechanisms.
- **Event Emission**: Emits detailed events for state changes (e.g., `UpdatedTokenInformation`, `ComplianceModuleAdded`, `TransferCompleted`).
- **Token Recovery**: Includes a `recoverERC20` function (requiring `_authorizeRecoverERC20` permission) to safely transfer out other ERC20 tokens mistakenly sent to the contract address. It cannot recover the contract's own token.
- **Standard & Upgradeable**: Provides both standard and UUPS upgradeable base contracts.

## Usage

To build a token using this extension:

1. **Choose Implementation**: Decide between `SMART` (standard) or `SMARTUpgradeable`.
2. **Inherit Base Contracts**:
    - Inherit your chosen implementation (`SMART` or `SMARTUpgradeable`).
    - Inherit an authorization contract implementing `_SMARTAuthorizationHooks` (e.g., `SMARTAccessControlAuthorization`).
    - **Upgradeable Only**: Inherit an access control contract for UUPS upgrades (e.g., `OwnableUpgradeable` or `AccessControlUpgradeable`).
3. **Implement Constructor/Initializer**:
    - **Standard (`SMART`)**: Create a `constructor` that calls the `SMART` constructor, passing all required parameters. Grant initial roles (e.g., `TOKEN_ADMIN_ROLE`, `MINTER_ROLE`) to the deployer or designated addresses.
    - **Upgradeable (`SMARTUpgradeable`)**: Create an `initialize` function. Inside, call the initializers for `ERC20Upgradeable`, `UUPSUpgradeable`, your chosen UUPS access control contract, your chosen authorization contract (if it has an initializer), AND finally `__SMARTUpgradeable_init`, passing all required parameters. Grant initial roles within the initializer.
4. **Implement Abstract Functions**: Ensure any abstract functions from inherited contracts (especially `_authorizeUpgrade` for `SMARTUpgradeable` and potentially `_msgSender`/`hasRole` if not using standard OZ AccessControl) are implemented in your final concrete contract.
5. **Deploy**: Deploy your final contract. For upgradeable contracts, deploy using a proxy pattern (e.g., via Hardhat Upgrades plugin).

## Authorization

The core logic relies on hooks defined in `_SMARTAuthorizationHooks` for permissioned actions. The `SMARTAccessControlAuthorization` contract provides a role-based implementation:

- `TOKEN_ADMIN_ROLE`: Can change token name, symbol, on-chain ID.
- `COMPLIANCE_ADMIN_ROLE`: Can manage the compliance contract address and compliance modules (add/remove/update parameters).
- `VERIFICATION_ADMIN_ROLE`: Can manage the identity registry address and required claim topics.
- `MINTER_ROLE`: Can mint new tokens.

These roles must be granted appropriately during deployment/initialization.

## Security Considerations

- **Role Management**: Securely manage who holds the admin roles. Compromise of these roles can lead to unauthorized changes in token settings, compliance rules, or supply.
- **Initialization (Upgradeable)**: Ensure the `initialize` function is properly secured (e.g., using OpenZeppelin's `Initializable` pattern) to prevent re-initialization attacks.
- **Upgradeability (UUPS)**: Secure the `_authorizeUpgrade` function diligently. Only trusted addresses (e.g., owner, governance multi-sig) should be able to authorize upgrades.
- **External Contracts**: The security of the SMART token depends heavily on the security and correctness of the configured `IdentityRegistry` and `Compliance` contracts and modules. Ensure these are audited and trusted.
- **Zero Address Checks**: The logic includes checks against setting critical addresses like compliance and identity registry to the zero address, preventing accidental misconfiguration.
