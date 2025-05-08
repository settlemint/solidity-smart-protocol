// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTPausableLogic } from "./internal/_SMARTPausableLogic.sol";

/// @title Upgradeable SMART Pausable Extension
/// @notice Upgradeable extension that adds pausable functionality to a SMART token.
/// @dev Inherits pausable logic from `_SMARTPausableLogic`, `SMARTExtensionUpgradeable`, and `Initializable`.
///      Applies the `whenNotPaused` modifier to the `_update` function to pause token transfers.
///      Expects the final contract to inherit `ERC20Upgradeable` and core `SMARTUpgradeable` logic.
///      Requires an accompanying authorization contract (e.g., `SMARTPausableAccessControlAuthorization`).
abstract contract SMARTPausableUpgradeable is Initializable, SMARTExtensionUpgradeable, _SMARTPausableLogic {
    // Note: Assumes the final contract inherits ERC20Upgradeable and SMARTUpgradeable

    // -- Initializer --
    /// @notice Initializes the pausable extension specific state.
    /// @dev Calls the initializer for PausableUpgradeable logic via `_SMARTPausableLogic` inheritance implicitly?
    ///      (OZ PausableUpgradeable doesn't have an explicit initializer, state is handled by _pause/_unpause)
    ///      This initializer is currently empty but provided for consistency.
    ///      Should be called within the main contract's `initialize` function.
    function __SMARTPausable_init() internal onlyInitializing { }

    // -- Internal Hooks & Overrides --

    /**
     * @notice Overrides the base ERC20Upgradeable `_update` function.
     * @dev Applies the `whenNotPaused` modifier (inherited from `_SMARTPausableLogic`)
     *      to ensure that token transfers (mints, burns, standard transfers)
     *      can only occur when the contract is not paused.
     *      Delegates the actual update logic to the parent implementation (likely `SMARTUpgradeable`).
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount being transferred.
     */
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC20Upgradeable) // Override the base ERC20 update
        whenNotPaused // Apply modifier from _SMARTPausableLogic
    {
        // super._update will call the next _update in the inheritance chain (e.g., SMARTUpgradeable's _update)
        super._update(from, to, value);
    }
}
