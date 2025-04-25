// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// Internal implementation imports
import { _SMARTBurnableAuthorizationHooks } from "./internal/_SMARTBurnableAuthorizationHooks.sol";

// Common errors
import { Unauthorized } from "../common/CommonErrors.sol";

/// @title Access Control Authorization for SMART Burnable Extension
/// @notice Implements authorization logic for the SMART Burnable extension using OpenZeppelin's AccessControl.
/// @dev Defines the `BURNER_ROLE` and requires the caller of burn operations to have this role.
///      Compatible with both standard and upgradeable AccessControl implementations.
abstract contract SMARTBurnableAccessControlAuthorization is _SMARTBurnableAuthorizationHooks {
    // -- Roles --

    /// @notice Role required to execute burn operations.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // -- Authorization Hook Implementation --

    /// @dev Authorizes burn operations.
    ///      Checks if the `_msgSender()` has the `BURNER_ROLE`.
    ///      Reverts with `Unauthorized` error if the sender lacks the role.
    /// @inheritdoc _SMARTBurnableAuthorizationHooks
    function _authorizeBurn() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(BURNER_ROLE, sender)) revert Unauthorized(sender);
    }

    // -- Abstract Dependencies (from AccessControl) --

    /// @dev Returns the address of the current message sender.
    function _msgSender() internal view virtual returns (address);

    /// @dev Checks if an account has a specific role.
    /// @param role The role identifier.
    /// @param account The address to check.
    /// @return True if the account has the role, false otherwise.
    function hasRole(bytes32 role, address account) public view virtual returns (bool);
}
