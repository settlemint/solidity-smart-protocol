// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// Internal implementation imports
import { _SMARTCustodianAuthorizationHooks } from "./internal/_SMARTCustodianAuthorizationHooks.sol";

/// @title SMARTAccessControlAuthorization
/// @notice Abstract authorization implementation for SMART tokens using OpenZeppelin's AccessControl,
///         compatible with both standard and upgradeable contracts.
/// @dev Defines roles for managing different aspects of the SMART token and implements authorization hooks.

abstract contract SMARTCustodianAccessControlAuthorization is _SMARTCustodianAuthorizationHooks {
    // --- Roles ---
    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");
    bytes32 public constant FORCED_TRANSFER_ROLE = keccak256("FORCED_TRANSFER_ROLE");
    bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE");

    // --- Authorization Hooks Implementation ---
    function _authorizeFreezeAddress() internal view virtual override returns (bool) {
        return hasRole(FREEZER_ROLE, _msgSender());
    }

    function _authorizeFreezePartialTokens() internal view virtual override returns (bool) {
        return hasRole(FREEZER_ROLE, _msgSender());
    }

    function _authorizeForcedTransfer() internal view virtual override returns (bool) {
        return hasRole(FORCED_TRANSFER_ROLE, _msgSender());
    }

    function _authorizeRecoveryAddress() internal view virtual override returns (bool) {
        return hasRole(RECOVERY_ROLE, _msgSender());
    }

    function _msgSender() internal view virtual returns (address);
    function hasRole(bytes32 role, address account) public view virtual returns (bool);
}
