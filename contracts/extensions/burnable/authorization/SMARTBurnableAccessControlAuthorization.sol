// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// openzeppelin imports
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

// SMART imports
import { SMARTExtensionAccessControlAuthorization } from "../../common/SMARTExtensionAccessControlAuthorization.sol";

// Internal implementation imports
import { _SMARTBurnableAuthorizationHooks } from "../internal/_SMARTBurnableAuthorizationHooks.sol";

/// @title Access Control Authorization for SMART Burnable Extension
/// @notice Implements authorization logic for the SMART Burnable extension using OpenZeppelin's AccessControl.
/// @dev Defines the `BURNER_ROLE` and requires the caller of burn operations to have this role.
///      Compatible with both standard and upgradeable AccessControl implementations.
abstract contract SMARTBurnableAccessControlAuthorization is
    _SMARTBurnableAuthorizationHooks,
    SMARTExtensionAccessControlAuthorization
{
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
        if (!hasRole(BURNER_ROLE, sender)) revert IAccessControl.AccessControlUnauthorizedAccount(sender, BURNER_ROLE);
    }
}
