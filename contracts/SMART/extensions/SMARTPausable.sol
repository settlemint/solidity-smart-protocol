// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";
import { SMARTHooks } from "./SMARTHooks.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// --- Custom Errors ---
error TokenPaused();

/// @title SMARTPausable
/// @notice Extension that adds pausable functionality to SMART tokens using OpenZeppelin's Pausable
abstract contract SMARTPausable is ERC20Pausable, SMARTHooks, ISMART, Ownable {
    // --- Constructor ---

    // --- Modifiers ---
    // Modifiers whenNotPaused and whenPaused are inherited from Pausable

    // --- State-Changing Functions ---
    /// @dev Triggers stopped state.
    /// Requires the contract not to be paused.
    /// Requires caller to have appropriate permission (e.g., owner).
    /// Emits a {Paused} event (from Pausable).
    function pause() public virtual onlyOwner {
        _pause();
    }

    /// @dev Returns to normal state.
    /// Requires the contract to be paused.
    /// Requires caller to have appropriate permission (e.g., owner).
    /// Emits an {Unpaused} event (from Pausable).
    function unpause() public virtual onlyOwner {
        _unpause();
    }

    // --- View Functions ---
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual override returns (bool) {
        // Added override specifier consistency
        return super.paused();
    }

    // --- Internal Functions ---
    /// @notice Override validation hooks to include pausing checks
    function _validateMint(address _to, uint256 _amount) internal virtual override {
        if (paused()) revert TokenPaused();
        super._validateMint(_to, _amount);
    }

    function _validateTransfer(address _from, address _to, uint256 _amount) internal virtual override {
        if (paused()) revert TokenPaused();
        super._validateTransfer(_from, _to, _amount);
    }

    /**
     * @dev Overrides _update to resolve conflict between ERC20Pausable and SMARTHooks,
     * ensuring the whenNotPaused modifier is applied.
     */
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC20Pausable, ERC20)
        whenNotPaused
    {
        super._update(from, to, value);
    }
}
