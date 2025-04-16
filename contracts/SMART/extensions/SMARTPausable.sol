// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";
import { SMARTHooks } from "./SMARTHooks.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// --- Custom Errors ---
error PausablePaused();
error PausableNotPaused();
error TokenPaused();

/// @title SMARTPausable
/// @notice Extension that adds pausable functionality to SMART tokens
abstract contract SMARTPausable is ERC20Pausable, SMARTHooks, ISMART {
    // --- Storage Variables ---
    bool private _paused; // Note: ERC20Pausable uses its own internal _paused state. This might be redundant unless
        // intended to override OZ behavior. Assuming override intention for now.

    // --- Constructor ---
    constructor() {
        _paused = false;
    }

    // --- Modifiers ---
    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier whenNotPaused() override {
        if (paused()) revert PausablePaused();
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused.
    modifier whenPaused() override {
        if (!paused()) revert PausableNotPaused();
        _;
    }

    // --- State-Changing Functions ---
    /// @dev Triggers stopped state.
    /// Requires the contract not to be paused.
    /// Emits a {Paused} event.
    function pause() public virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @dev Returns to normal state.
    /// Requires the contract to be paused.
    /// Emits an {Unpaused} event.
    function unpause() public virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    // --- View Functions ---
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual override returns (bool) {
        // Added override specifier consistency
        return _paused;
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

    // Note: The _update override might be implicitly handled by _beforeTokenTransfer hook in OZ ERC20Pausable
    // Keeping explicit override for clarity if needed, but ensure it doesn't conflict.
    // If using OZ ERC20Pausable as intended, its _update likely handles the pause check via _beforeTokenTransfer.
    // This override might be unnecessary or potentially problematic if the goal is just to add SMART hooks.
    // Let's remove it for now, relying on the _beforeTokenTransfer hook.
    // function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) {
    //     // require(!paused(), "Token is paused"); // Check moved to _beforeTokenTransfer
    //     super._update(from, to, value);
    // }

    // OZ ERC20Pausable overrides _update, which internally calls _beforeTokenTransfer.
    // We override _beforeTokenTransfer above. If additional logic is needed specific
    // to _update beyond the pause check, it can be added here.
    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) {
        // If SMARTPausable needs logic *in addition* to the pause check during _update, add it here.
        // Otherwise, just calling super is correct as the pause check happens in _beforeTokenTransfer.
        super._update(from, to, value);
    }
}
