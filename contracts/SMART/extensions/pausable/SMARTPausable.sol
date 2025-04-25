// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Note: We don't inherit ERC20Pausable directly to avoid state variable clashes if _SMARTPausableLogic is used.
// Instead, we inherit Pausable logic via _SMARTPausableLogic and re-apply the modifier.
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTPausableLogic } from "./internal/_SMARTPausableLogic.sol";

/// @title Standard SMART Pausable Extension
/// @notice Standard (non-upgradeable) extension that adds pausable functionality to a SMART token.
/// @dev Inherits pausable logic from `_SMARTPausableLogic` and `SMARTExtension`.
///      Applies the `whenNotPaused` modifier to the `_update` function to pause token transfers.
///      Expects the final contract to inherit a standard `ERC20` implementation and core `SMART` logic.
///      Requires an accompanying authorization contract (e.g., `SMARTPausableAccessControlAuthorization`).
abstract contract SMARTPausable is SMARTExtension, _SMARTPausableLogic {
    // Note: Assumes the final contract inherits ERC20 and SMART

    // -- Internal Hooks & Overrides --

    /**
     * @notice Overrides the base ERC20 `_update` function.
     * @dev Applies the `whenNotPaused` modifier (inherited from `_SMARTPausableLogic`)
     *      to ensure that token transfers (mints, burns, standard transfers)
     *      can only occur when the contract is not paused.
     *      Delegates the actual update logic to the parent implementation (likely `SMART`).
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount being transferred.
     */
    function _update(address from, address to, uint256 value) internal virtual override(ERC20) whenNotPaused {
        // Note: The whenNotPaused modifier comes from _SMARTPausableLogic
        // super._update will call the next _update in the inheritance chain (e.g., SMART's _update)
        super._update(from, to, value);
    }

    /// @dev Overrides `_msgSender` to resolve inheritance conflict between `_SMARTPausableLogic` and base contracts.
    ///      Delegates to the base implementation (ultimately from OZ Context).
    function _msgSender() internal view virtual override(Context, _SMARTPausableLogic) returns (address) {
        return super._msgSender();
    }
}
