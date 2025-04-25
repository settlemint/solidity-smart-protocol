# SMART Custodian Extension

This extension provides custodial control features for SMART tokens, typically managed by authorized roles. It allows for freezing addresses or specific token amounts, performing forced transfers, and recovering assets from lost wallets.

## Overview

The custodian extension adds a layer of administrative control over token movements and states, crucial for certain regulatory environments or recovery scenarios.

Key components include:

- **`_SMARTCustodianLogic.sol`**: An internal abstract contract holding the state (`__frozen`, `__frozenTokens`) and core logic for freezing, unfreezing, forced transfers, and recovery (`_setAddressFrozen`, `_freezePartialTokens`, `_forcedTransferLogic`, `_recoveryAddressLogic`). It defines abstract functions (`_getBalance`, `_executeTransferUpdate`, `identityRegistry`) that must be implemented by inheriting contracts.
- **`_SMARTCustodianAuthorizationHooks.sol`**: Defines abstract internal authorization hooks (`_authorizeFreezeAddress`, `_authorizeForcedTransfer`, etc.) called by `_SMARTCustodianLogic`.
- **`SMARTCustodianAccessControlAuthorization.sol`**: An example authorization implementation using OpenZeppelin's AccessControl. It defines roles (`FREEZER_ROLE`, `FORCED_TRANSFER_ROLE`, `RECOVERY_ROLE`) and implements the authorization hooks.
- **`SMARTCustodian.sol`**: The standard (non-upgradeable) implementation. It inherits `_SMARTCustodianLogic` and `SMARTExtension`. It implements the abstract `_getBalance` and `_executeTransferUpdate` using standard ERC20 functions and overrides `SMARTHooks` (`_beforeMint`, `_beforeTransfer`, etc.) to integrate custodian checks.
- **`SMARTCustodianUpgradeable.sol`**: The upgradeable implementation. It inherits `_SMARTCustodianLogic`, `SMARTExtensionUpgradeable`, and `Initializable`. It implements the abstract dependencies using `ERC20Upgradeable` functions and overrides `SMARTHooks` similarly to the standard version. Includes an initializer `__SMARTCustodian_init`.

## Features

- **Address Freezing:** Freeze/unfreeze entire addresses, preventing standard transfers (`FREEZER_ROLE` required).
- **Partial Token Freezing:** Freeze/unfreeze specific amounts of tokens for an address (`FREEZER_ROLE` required).
- **Forced Transfers:** Allow authorized transfer of tokens *from* any address *to* any address, bypassing standard transfer rules and automatically unfreezing tokens if needed (`FORCED_TRANSFER_ROLE` required).
- **Address Recovery:** Facilitate asset recovery from a lost/compromised wallet to a new wallet linked to the same verified identity. Transfers balance, frozen status, and updates the identity registry (`RECOVERY_ROLE` required, plus `REGISTRAR_ROLE` on Identity Registry).
- **Transfer Control Integration:** Hooks into standard token operations (`_beforeMint`, `_beforeTransfer`, `_beforeBurn`, `_beforeRedeem`) to enforce freezing rules (e.g., block transfers involving frozen addresses, require sufficient *unfrozen* balance for standard transfers/redeems).

## Usage

To use this extension:

1. **Inherit Base Contracts**:
    - Inherit the core `SMART` or `SMARTUpgradeable` implementation.
    - Inherit the corresponding custodian implementation (`SMARTCustodian` or `SMARTCustodianUpgradeable`).
    - Inherit an authorization contract implementing `_SMARTCustodianAuthorizationHooks` (e.g., `SMARTCustodianAccessControlAuthorization`).
    - Inherit necessary base contracts (e.g., `ERC20`/`ERC20Upgradeable`, `AccessControlUpgradeable`/`OwnableUpgradeable` if applicable).
2. **Implement Constructor/Initializer**:
    - **Standard (`SMARTCustodian`)**: In the final contract's `constructor`, call the constructors of parent contracts (like `SMART`). Grant initial custodian roles (`FREEZER_ROLE`, etc.).
    - **Upgradeable (`SMARTCustodianUpgradeable`)**: In the final contract's `initialize` function, call initializers for parent contracts (e.g., `__ERC20_init`, `__AccessControl_init`, `__SMARTUpgradeable_init`) and then call `__SMARTCustodian_init()`. Grant initial custodian roles.
3. **Implement Abstract Functions**: Ensure `identityRegistry()` and `requiredClaimTopics()` from `_SMARTCustodianLogic` are implemented (usually by inheriting the core `SMART` or `SMARTUpgradeable` which provides these).
4. **Grant Roles**: Grant the necessary roles (`FREEZER_ROLE`, `FORCED_TRANSFER_ROLE`, `RECOVERY_ROLE`) to the appropriate admin/custodian addresses.
5. **Identity Registry Permission**: Ensure the token contract address has the `REGISTRAR_ROLE` on the configured `IdentityRegistry` contract to allow the `recoveryAddress` function to update registrations.

## Authorization

The `SMARTCustodianAccessControlAuthorization` contract provides a role-based implementation:

- `FREEZER_ROLE`: Can freeze/unfreeze addresses and specific token amounts.
- `FORCED_TRANSFER_ROLE`: Can execute `forcedTransfer` and `batchForcedTransfer`.
- `RECOVERY_ROLE`: Can execute `recoveryAddress`.

These roles must be granted securely.

## Security Considerations

- **Role Management**: The custodian roles grant significant power. Compromise of these roles can lead to unauthorized freezing, asset seizure (via forced transfer), or potentially incorrect recovery actions. Manage these roles with extreme care (e.g., using multi-sig wallets).
- **Forced Transfer**: This function bypasses standard compliance and verification checks enforced by `_beforeTransfer`. Use it only when absolutely necessary and ensure the destination address is appropriate.
- **Recovery**: The recovery function relies heavily on the `IdentityRegistry`'s correctness and the verification status of the wallets involved. Ensure the registry is secure and the process for verifying identities is robust. Requires `REGISTRAR_ROLE` on the registry, which itself is a sensitive permission.
- **Interaction with Other Extensions**: Custodian actions might interact with other extensions (e.g., burning frozen tokens). Ensure these interactions are understood and tested.
