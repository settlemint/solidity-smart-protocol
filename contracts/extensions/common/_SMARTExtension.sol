// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { ISMART } from "../../interface/ISMART.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";
import { SMARTContext } from "../common/SMARTContext.sol";
import { ZeroAddressNotAllowed, CannotRecoverSelf, InvalidLostWallet, NoTokensToRecover } from "./CommonErrors.sol";
import { ISMARTIdentityRegistry } from "../../interface/ISMARTIdentityRegistry.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";

/// @title Base Contract for All SMART Token Extensions
/// @notice This abstract contract serves as the ultimate base for all SMART token extensions,
///         both standard and upgradeable. It provides fundamental shared functionalities like
///         interface registration for ERC165 support and inherits core SMART interfaces and hook definitions.
/// @dev It inherits `ISMART` (the core interface for SMART tokens, defining functions like `onchainID`,
///      `identityRegistry`, etc.), `SMARTContext` (for a consistent way to get the transaction sender),
///      and `SMARTHooks` (which defines the standard set of lifecycle hooks like `_beforeMint`).
///      The `_isInterfaceRegistered` mapping and `_registerInterface` function are used to implement
///      ERC165 introspection, allowing other contracts to query if a SMART token supports a specific extension
/// interface.
///      An 'abstract contract' is a template and cannot be deployed directly.

abstract contract _SMARTExtension is ISMART, SMARTContext, SMARTHooks {
    /// @notice Internal flag, potentially for managing forced updates or states (usage may vary or be vestigial).
    /// @dev The exact purpose of `__isForcedUpdate` might depend on specific extension implementations or
    ///      higher-level contract logic that uses it. It's a general-purpose internal flag.
    bool internal __isForcedUpdate; // TODO: Review if this is actively used or can be deprecated/clarified.

    /// @notice Mapping to store registered interface IDs for ERC165 support.
    /// @dev ERC165 allows contracts to declare which interfaces they implement. This mapping stores
    ///      `bytes4` interface identifiers (derived from function signatures) as keys and a boolean
    ///      indicating if that interface is supported (`true`) or not (`false`).
    ///      This allows for an efficient O(1) (constant time) lookup when checking for interface support
    ///      via a `supportsInterface(bytes4)` function (which would typically be implemented in a more concrete
    /// contract
    ///      like `ERC165.sol` or `SMART.sol` that inherits this).
    mapping(bytes4 interfaceId => bool isRegistered) internal _isInterfaceRegistered;

    // --- Abstract Functions ---

    /// @notice Abstract function placeholder for the actual token transfer mechanism.
    /// @dev Similar to `__smart_executeMint`, this is implemented by child contracts to call the
    ///      underlying ERC20 `_transfer` function.
    /// @param from The address from which tokens are sent.
    /// @param to The address to which tokens are sent.
    /// @param amount The quantity of tokens to transfer.
    function __smartExtension_executeTransfer(address from, address to, uint256 amount) internal virtual;

    /// @notice Abstract function placeholder for the actual token balance retrieval mechanism.
    /// @dev This function is implemented by child contracts to call the underlying ERC20 `balanceOf` function.
    /// @param account The address to query the balance of.
    /// @return The balance of the specified account.
    function __smartExtension_balanceOf(address account) internal virtual returns (uint256);

    // --- Implementation Functions ---

    /**
     * @notice Registers a specific interface ID as being supported by this contract.
     * @dev This internal function is intended to be called by derived extension contracts, usually during
     *      their initialization phase (constructor for standard, or an initializer function for upgradeable).
     *      By calling this, an extension signals that it implements all functions defined in the given interface.
     *      For example, a burnable extension would call `_registerInterface(type(ISMARTBurnable).interfaceId);`.
     *      This populates the `_isInterfaceRegistered` mapping.
     * @param interfaceId The `bytes4` identifier of the interface to register (e.g.,
     * `type(IMyExtensionInterface).interfaceId`).
     *                    The `type(IMyInterface).interfaceId` expression automatically calculates the correct ERC165
     * ID.
     */
    function _registerInterface(bytes4 interfaceId) internal {
        _isInterfaceRegistered[interfaceId] = true;
    }

    /// @notice Internal function to recover tokens from a lost wallet.
    /// @dev This function performs a series of checks and actions to ensure the recovery is valid and secure.
    ///      It first checks if the lost wallet is a valid address and not the contract itself.
    ///      Then, it checks if the lost wallet has any tokens to recover.
    ///      It then checks if the new wallet is a valid address.
    function _smart_recoverTokens(address lostWallet, address newWallet) internal {
        if (lostWallet == address(0)) revert ZeroAddressNotAllowed();
        if (lostWallet == address(this)) revert CannotRecoverSelf();

        uint256 balance = __smartExtension_balanceOf(lostWallet);
        if (balance == 0) revert NoTokensToRecover();

        ISMARTIdentityRegistry registry = this.identityRegistry();
        IIdentity identity = registry.identity(newWallet);
        bool isLost = registry.isWalletLostForIdentity(identity, lostWallet);
        if (!isLost) revert InvalidLostWallet();

        _beforeRecoverTokens(lostWallet, newWallet);
        __isForcedUpdate = true;
        __smartExtension_executeTransfer(lostWallet, newWallet, balance);
        __isForcedUpdate = false;
        _afterRecoverTokens(lostWallet, newWallet);
    }
}
