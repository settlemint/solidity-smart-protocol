// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// Internal implementation imports
import { _SMARTPausableAuthorizationHooks } from "./internal/_SMARTPausableAuthorizationHooks.sol";

// Common errors
import { Unauthorized } from "../common/CommonErrors.sol";

/// @title Access Control Authorization for SMART Pausable Extension
/// @notice Implements authorization logic for the SMART Pausable features using OpenZeppelin's AccessControl.
/// @dev Defines the `PAUSER_ROLE` and implements the `_authorizePause` hook from `_SMARTPausableAuthorizationHooks`.
///      Compatible with both standard and upgradeable AccessControl implementations.

abstract contract SMARTPausableAccessControlAuthorization is _SMARTPausableAuthorizationHooks {
    // --- Roles ---
    /// @notice Role required to pause or unpause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // --- Authorization Hooks Implementation ---
    /// @dev Authorizes pausing or unpausing the contract.
    ///      Checks if the `_msgSender()` has the `PAUSER_ROLE`.
    /// @inheritdoc _SMARTPausableAuthorizationHooks
    function _authorizePause() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(PAUSER_ROLE, sender)) revert Unauthorized(sender);
    }

    // --- Abstract Dependencies (from AccessControl) ---

    /// @dev Returns the address of the current message sender.
    ///      Needs to be implemented by the inheriting contract (usually provided by OZ AccessControl).
    function _msgSender() internal view virtual returns (address);

    /// @dev Checks if an account has a specific role.
    ///      Needs to be implemented by the inheriting contract (usually provided by OZ AccessControl).
    /// @param role The role identifier.
    /// @param account The address to check.
    /// @return True if the account has the role, false otherwise.
    function hasRole(bytes32 role, address account) public view virtual returns (bool);
}
