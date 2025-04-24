// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// Internal implementation imports
import { _SMARTPausableAuthorizationHooks } from "./internal/_SMARTPausableAuthorizationHooks.sol";

/// @title SMARTAccessControlAuthorization
/// @notice Abstract authorization implementation for SMART tokens using OpenZeppelin's AccessControl,
///         compatible with both standard and upgradeable contracts.
/// @dev Defines roles for managing different aspects of the SMART token and implements authorization hooks.

abstract contract SMARTPausableAccessControlAuthorization is _SMARTPausableAuthorizationHooks {
    // --- Roles ---
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // --- Authorization Hooks Implementation ---
    function _authorizePause() internal view virtual override returns (bool) {
        return hasRole(PAUSER_ROLE, _msgSender());
    }

    function _msgSender() internal view virtual returns (address);
    function hasRole(bytes32 role, address account) public view virtual returns (bool);
}
