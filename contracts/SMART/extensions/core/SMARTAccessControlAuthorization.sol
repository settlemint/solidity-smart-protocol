// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { _SMARTAuthorizationHooks } from "./internal/_SMARTAuthorizationHooks.sol";

/// @title SMARTAccessControlAuthorization
/// @notice Abstract authorization implementation for SMART tokens using OpenZeppelin's AccessControl,
///         compatible with both standard and upgradeable contracts.
/// @dev Defines roles for managing different aspects of the SMART token and implements authorization hooks.

abstract contract SMARTAccessControlAuthorization is _SMARTAuthorizationHooks {
    // --- Roles ---
    bytes32 public constant TOKEN_ADMIN_ROLE = keccak256("TOKEN_ADMIN_ROLE");
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");
    bytes32 public constant VERIFICATION_ADMIN_ROLE = keccak256("VERIFICATION_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // --- Authorization Hooks Implementation ---

    /// @dev Checks if the caller has the TOKEN_ADMIN_ROLE.
    function _auhtorizeUpdateTokenSettings() internal view virtual override returns (bool) {
        return hasRole(TOKEN_ADMIN_ROLE, _msgSender());
    }

    /// @dev Checks if the caller has the COMPLIANCE_ADMIN_ROLE.
    function _authorizeUpdateComplianceSettings() internal view virtual override returns (bool) {
        return hasRole(COMPLIANCE_ADMIN_ROLE, _msgSender());
    }

    /// @dev Checks if the caller has the VERIFICATION_ADMIN_ROLE.
    function _authorizeUpdateVerificationSettings() internal view virtual override returns (bool) {
        return hasRole(VERIFICATION_ADMIN_ROLE, _msgSender());
    }

    /// @dev Checks if the caller has the MINTER_ROLE.
    function _authorizeMintToken() internal view virtual override returns (bool) {
        return hasRole(MINTER_ROLE, _msgSender());
    }

    function _msgSender() internal view virtual returns (address);
    function hasRole(bytes32 role, address account) public view virtual returns (bool);
}
