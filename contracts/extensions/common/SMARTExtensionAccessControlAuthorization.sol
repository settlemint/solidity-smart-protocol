// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// SMART imports
import { SMARTContext } from "./SMARTContext.sol";

/// @title SMARTExtension
/// @notice Abstract contract that defines the internal hooks for standard SMART tokens.
/// @dev Base for standard SMART extensions, inheriting ERC20.
///      These hooks should be called first in any override implementation.

abstract contract SMARTExtensionAccessControlAuthorization {
    // -- Abstract Dependencies (from AccessControl) --

    /// @dev Checks if an account has a specific role.
    /// @param role The role identifier.
    /// @param account The address to check.
    /// @return True if the account has the role, false otherwise.
    function hasRole(bytes32 role, address account) public view virtual returns (bool);

    /// @dev Returns the address of the current message sender.
    ///      Needs to be implemented by the inheriting contract (usually provided by OZ AccessControl).
    function _msgSender() internal view virtual returns (address);
}
