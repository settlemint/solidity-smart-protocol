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
/// @notice This contract is a dedicated manager for handling roles and permissions across multiple
///         SMART token contracts. Instead of each token managing its own access control, they can
///         delegate these checks to an instance of this `SMARTTokenAccessManager`.
///         This promotes consistency, simplifies role management (as roles are managed in one place),
///         and can save gas by deploying this logic once and reusing it.
/// @dev This contract inherits from OpenZeppelin's `AccessControlEnumerable` to get robust
///      role-based access control features (like granting, revoking, renouncing roles, and enumerating
///      role members) and `ERC2771Context` to support meta-transactions.
///      Meta-transactions allow users to interact with contracts without needing ETH for gas fees,
///      as a trusted "forwarder" can relay their transactions.
contract SMARTTokenAccessManager is ISMARTTokenAccessManager, AccessControlEnumerable, ERC2771Context {
    // Note: DEFAULT_ADMIN_ROLE is a special role (bytes32(0)) inherited from OpenZeppelin's AccessControl.
    // Accounts with this role can manage other roles (grant/revoke them).

    /// @notice Constructor that sets up the access manager.
    /// @dev When this contract is deployed, the `constructor` is executed once.
    ///      It initializes the `ERC2771Context` with the provided `forwarder` address.
    ///      Crucially, it grants the `DEFAULT_ADMIN_ROLE` to the `sender` (the account deploying this contract).
    ///      This gives the deployer initial administrative control over the access manager.
    ///      The `_msgSender()` function (from `ERC2771Context`) is used to correctly identify the
    ///      sender, even if the deployment is done via a trusted forwarder (meta-transaction).
    /// @param forwarder The address of the trusted forwarder contract. If not using meta-transactions,
    ///                  this can be `address(0)`, but ensure compatibility with `ERC2771Context` behavior.
    /// @param initialAdmin Address of the initial admin for the token.
    constructor(address forwarder, address initialAdmin) AccessControlEnumerable() ERC2771Context(forwarder) {
        // Grant standard admin role (can manage other roles)
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /// @notice Checks if a given account has a specific role.
    /// @dev This function implements `hasRole` from both `ISMARTTokenAccessManager` and OpenZeppelin's
    /// `IAccessControl`.
    ///      It directly uses the `hasRole` function inherited from OpenZeppelin's `AccessControl` contract,
    ///      which contains the actual logic for checking role assignments.
    ///      The `override` keyword is used because this function is redefining a function from its parent
    /// contracts/interfaces.
    ///      The `virtual` keyword indicates that this function can, in turn, be overridden by contracts that inherit
    /// from `SMARTTokenAccessManager`.
    /// @param role The `bytes32` identifier of the role to check.
    /// @param account The address of the account whose roles are being checked.
    /// @return `true` if the account has the specified role, `false` otherwise.
    function hasRole(
        bytes32 role,
        address account
    )
        public
        view
        virtual
        override(ISMARTTokenAccessManager, AccessControl, IAccessControl) // Specifies which functions are being
            // overridden
        returns (bool)
    {
        return AccessControl.hasRole(role, account);
    }

    /// @notice Grants `role` to each address in `accounts`.
    /// @param role The role identifier to grant.
    /// @param accounts The addresses that will receive the role.
    function batchGrantRole(bytes32 role, address[] calldata accounts) external override {
        uint256 length = accounts.length;
        for (uint256 i = 0; i < length;) {
            grantRole(role, accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Revokes `role` from each address in `accounts`.
    /// @param role The role identifier to revoke.
    /// @param accounts The addresses that will lose the role.
    function batchRevokeRole(bytes32 role, address[] calldata accounts) external override {
        uint256 length = accounts.length;
        for (uint256 i = 0; i < length;) {
            revokeRole(role, accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Overrides the `_msgSender()` function to support meta-transactions via ERC2771.
    /// @dev This internal function is crucial for contracts that use `ERC2771Context`.
    ///      When a function call is relayed through a trusted forwarder, `msg.sender` would be
    ///      the forwarder's address. `_msgSender()` correctly identifies the original user
    ///      who initiated the transaction.
    ///      This ensures that access control checks and role assignments are based on the
    ///      actual user, not the intermediary forwarder.
    /// @return The address of the original transaction initiator.
    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return super._msgSender(); // Calls the implementation from ERC2771Context
    }

    /// @notice Overrides the `_msgData()` function to support meta-transactions via ERC2771.
    /// @dev Similar to `_msgSender()`, this function retrieves the original call data when a
    ///      transaction is relayed through a trusted forwarder.
    /// @return The original `msg.data` from the user's transaction.
    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return super._msgData(); // Calls the implementation from ERC2771Context
    }

    /// @notice Overrides `_contextSuffixLength` for ERC2771 compatibility.
    /// @dev This function is part of the ERC2771 standard, indicating if the calldata includes
    ///      a suffix with the sender's address (appended by the forwarder).
    /// @return The length of the context suffix if present, otherwise 0.
    function _contextSuffixLength() internal view virtual override(Context, ERC2771Context) returns (uint256) {
        return super._contextSuffixLength(); // Calls the implementation from ERC2771Context
    }

    /// @notice Declares support for interfaces, including `ISMARTTokenAccessManager`.
    /// @dev This function allows other contracts to query if this contract implements a specific interface,
    ///      adhering to the ERC165 standard (Standard Interface Detection).
    ///      It checks if the given `interfaceId` matches `type(ISMARTTokenAccessManager).interfaceId`
    ///      or any interface supported by its parent `AccessControlEnumerable` (which includes ERC165 itself
    ///      and `IAccessControlEnumerable`).
    /// @param interfaceId The bytes4 identifier of the interface to check for support.
    /// @return `true` if the contract supports the interface, `false` otherwise.
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
