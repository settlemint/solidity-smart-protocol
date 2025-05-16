// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

// OpenZeppelin imports
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

// Interface import
import { ISMARTTokenAccessManager } from "./ISMARTTokenAccessManager.sol";

/// @title Centralized Access Control Manager for SMART Tokens
/// @notice Manages roles and provides authorization checks for various SMART token operations.
///         Intended to be used by SMART token contracts that inherit `SMARTTokenAccessControlManaged`.
contract SMARTTokenAccessManager is ISMARTTokenAccessManager, AccessControlEnumerable, ERC2771Context {
    // Note: DEFAULT_ADMIN_ROLE is inherited from AccessControl

    /// @dev Constructor grants initial roles to the deployer.
    /// @param forwarder Address of the trusted forwarder for ERC2771 meta-transactions.
    constructor(address forwarder) ERC2771Context(forwarder) {
        address sender = _msgSender(); // Use _msgSender() to support deployment via forwarder

        // Grant standard admin role (can manage other roles)
        _grantRole(DEFAULT_ADMIN_ROLE, sender);
    }

    /// @inheritdoc AccessControl
    function hasRole(
        bytes32 role,
        address account
    )
        public
        view
        virtual
        override(ISMARTTokenAccessManager, AccessControl, IAccessControl)
        returns (bool)
    {
        return AccessControl.hasRole(role, account);
    }

    /// @inheritdoc ERC2771Context
    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return super._msgSender(); // Use ERC2771Context's implementation
    }

    /// @inheritdoc ERC2771Context
    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return super._msgData(); // Use ERC2771Context's implementation
    }

    /// @inheritdoc ERC2771Context
    function _contextSuffixLength() internal view virtual override(Context, ERC2771Context) returns (uint256) {
        return super._contextSuffixLength(); // Use ERC2771Context's implementation
    }

    /// @inheritdoc AccessControlEnumerable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable)
        returns (bool)
    {
        return interfaceId == type(ISMARTTokenAccessManager).interfaceId || super.supportsInterface(interfaceId);
    }
}
