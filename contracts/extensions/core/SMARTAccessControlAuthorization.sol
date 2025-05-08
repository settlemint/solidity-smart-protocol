// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// openzeppelin imports
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

// SMART imports
import { SMARTExtensionAccessControlAuthorization } from "../common/SMARTExtensionAccessControlAuthorization.sol";

// Internal implementation imports
import { _SMARTAuthorizationHooks } from "./internal/_SMARTAuthorizationHooks.sol";

/// @title Access Control Authorization for Core SMART Functionality
/// @notice Implements authorization logic for the core SMART operations using OpenZeppelin's AccessControl.
/// @dev Defines specific roles (TOKEN_ADMIN, COMPLIANCE_ADMIN, VERIFICATION_ADMIN, MINTER)
///      and implements the authorization hooks from `_SMARTAuthorizationHooks` to enforce these roles.
///      Compatible with both standard and upgradeable AccessControl implementations.
abstract contract SMARTAccessControlAuthorization is
    _SMARTAuthorizationHooks,
    SMARTExtensionAccessControlAuthorization
{
    // -- Roles --
    /// @notice Role required to update general token settings (name, symbol, onchainID).
    bytes32 public constant TOKEN_ADMIN_ROLE = keccak256("TOKEN_ADMIN_ROLE");
    /// @notice Role required to update compliance settings (compliance contract, modules, parameters).
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");
    /// @notice Role required to update verification settings (identity registry, required claim topics).
    bytes32 public constant VERIFICATION_ADMIN_ROLE = keccak256("VERIFICATION_ADMIN_ROLE");
    /// @notice Role required to mint new tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // -- Authorization Hook Implementations --

    /// @dev Authorizes updates to token settings.
    ///      Checks if the `_msgSender()` has the `TOKEN_ADMIN_ROLE`.
    /// @inheritdoc _SMARTAuthorizationHooks
    function _authorizeUpdateTokenSettings() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(TOKEN_ADMIN_ROLE, sender)) {
            revert IAccessControl.AccessControlUnauthorizedAccount(sender, TOKEN_ADMIN_ROLE);
        }
    }

    /// @dev Authorizes updates to compliance settings.
    ///      Checks if the `_msgSender()` has the `COMPLIANCE_ADMIN_ROLE`.
    /// @inheritdoc _SMARTAuthorizationHooks
    function _authorizeUpdateComplianceSettings() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(COMPLIANCE_ADMIN_ROLE, sender)) {
            revert IAccessControl.AccessControlUnauthorizedAccount(sender, COMPLIANCE_ADMIN_ROLE);
        }
    }

    /// @dev Authorizes updates to verification settings.
    ///      Checks if the `_msgSender()` has the `VERIFICATION_ADMIN_ROLE`.
    /// @inheritdoc _SMARTAuthorizationHooks
    function _authorizeUpdateVerificationSettings() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(VERIFICATION_ADMIN_ROLE, sender)) {
            revert IAccessControl.AccessControlUnauthorizedAccount(sender, VERIFICATION_ADMIN_ROLE);
        }
    }

    /// @dev Authorizes minting of new tokens.
    ///      Checks if the `_msgSender()` has the `MINTER_ROLE`.
    /// @inheritdoc _SMARTAuthorizationHooks
    function _authorizeMintToken() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(MINTER_ROLE, sender)) revert IAccessControl.AccessControlUnauthorizedAccount(sender, MINTER_ROLE);
    }

    /// @dev Authorizes recovering mistakenly sent ERC20 tokens from the contract.
    ///      Checks if the `_msgSender()` has the `RECOVER_ERC20_ROLE`.
    /// @inheritdoc _SMARTAuthorizationHooks
    function _authorizeRecoverERC20() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(TOKEN_ADMIN_ROLE, sender)) {
            revert IAccessControl.AccessControlUnauthorizedAccount(sender, TOKEN_ADMIN_ROLE);
        }
    }
}
