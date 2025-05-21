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

    /// @notice Role for token identity registration
    /// @dev Assigned to entities responsible for registering new token identities
    bytes32 public constant TOKEN_REGISTRAR_ROLE = keccak256("TOKEN_REGISTRAR_ROLE");

    /// @notice Role for managing token identity registrars
    /// @dev Assigned to entities responsible for overseeing token identity registration operations
    bytes32 public constant TOKEN_REGISTRAR_MANAGER_ROLE = keccak256("TOKEN_REGISTRAR_MANAGER_ROLE");
}
