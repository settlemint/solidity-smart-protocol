// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// openzeppelin imports
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

// SMART imports
import { SMARTExtensionAccessControlAuthorization } from "../common/SMARTExtensionAccessControlAuthorization.sol";

// Internal implementation imports
import { _SMARTPausableAuthorizationHooks } from "./internal/_SMARTPausableAuthorizationHooks.sol";

/// @title Access Control Authorization for SMART Pausable Extension
/// @notice Implements authorization logic for the SMART Pausable features using OpenZeppelin's AccessControl.
/// @dev Defines the `PAUSER_ROLE` and implements the `_authorizePause` hook from `_SMARTPausableAuthorizationHooks`.
///      Compatible with both standard and upgradeable AccessControl implementations.

abstract contract SMARTPausableAccessControlAuthorization is
    _SMARTPausableAuthorizationHooks,
    SMARTExtensionAccessControlAuthorization
{
    // --- Roles ---
    /// @notice Role required to pause or unpause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // --- Authorization Hooks Implementation ---
    /// @dev Authorizes pausing or unpausing the contract.
    ///      Checks if the `_msgSender()` has the `PAUSER_ROLE`.
    /// @inheritdoc _SMARTPausableAuthorizationHooks
    function _authorizePause() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(PAUSER_ROLE, sender)) revert IAccessControl.AccessControlUnauthorizedAccount(sender, PAUSER_ROLE);
    }
}
