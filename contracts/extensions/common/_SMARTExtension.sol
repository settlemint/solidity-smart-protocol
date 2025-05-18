// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { ISMART } from "../../interface/ISMART.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";
import { SMARTContext } from "../common/SMARTContext.sol";

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
}
