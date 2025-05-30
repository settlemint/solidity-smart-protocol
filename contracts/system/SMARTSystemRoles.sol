// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

/// @title SMARTSystemRoles
/// @notice Library defining role constants for the SMART protocol's access control system
/// @dev These roles are used with OpenZeppelin's AccessControl contract
library SMARTSystemRoles {
    /// @notice The default admin role that can grant and revoke other roles
    /// @dev Matches the default admin role in OpenZeppelin's AccessControl
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @notice Role for managing registration operations
    /// @dev Assigned to entities responsible for user registration
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    /// @notice Role for managing claims
    /// @dev Assigned to entities responsible for handling token claims
    bytes32 public constant CLAIM_MANAGER_ROLE = keccak256("CLAIM_MANAGER_ROLE");

    /// @notice Role for managing identity issuers
    /// @dev Assigned to entities responsible for handling identity issuers
    bytes32 public constant IDENTITY_ISSUER_ROLE = keccak256("IDENTITY_ISSUER_ROLE");

    /// @notice Role for token identity issuers
    /// @dev Assigned to entities responsible for issuing new token identities
    bytes32 public constant TOKEN_IDENTITY_ISSUER_ROLE = keccak256("TOKEN_IDENTITY_ISSUER_ROLE");

    /// @notice Role for managing token identity issuers
    /// @dev Assigned to entities responsible for managing token identity issuers
    bytes32 public constant TOKEN_IDENTITY_ISSUER_ADMIN_ROLE = keccak256("TOKEN_IDENTITY_ISSUER_ADMIN_ROLE");

    /// @notice Role for token deployers
    /// @dev Assigned to entities responsible for deploying new tokens
    bytes32 public constant TOKEN_DEPLOYER_ROLE = keccak256("TOKEN_DEPLOYER_ROLE");

    /// @notice A unique identifier (hash) for the role that grants permission to modify the data stored in this
    /// contract.
    /// @dev This role is typically granted to `SMARTIdentityRegistry` contracts that are "bound" to this storage.
    /// Only addresses holding this role can call functions like `addIdentityToStorage`, `removeIdentityFromStorage`,
    /// `modifyStoredIdentity`, and `modifyStoredInvestorCountry`.
    /// The value is calculated as `keccak256("STORAGE_MODIFIER_ROLE")`.
    bytes32 public constant STORAGE_MODIFIER_ROLE = keccak256("STORAGE_MODIFIER_ROLE");

    /// @notice A unique identifier (hash) for the role that grants permission to manage the list of bound identity
    /// registry contracts.
    /// @dev Addresses holding this role can call `bindIdentityRegistry` to authorize a new registry contract and
    /// `unbindIdentityRegistry` to revoke authorization from an existing one.
    /// This role is crucial for controlling which external contracts can write to this storage.
    /// It is typically assigned to a high-level system management contract (e.g., `SMARTSystem` or an identity factory
    /// contract).
    /// The value is calculated as `keccak256("MANAGE_REGISTRIES_ROLE")`.
    bytes32 public constant MANAGE_REGISTRIES_ROLE = keccak256("MANAGE_REGISTRIES_ROLE");
}
