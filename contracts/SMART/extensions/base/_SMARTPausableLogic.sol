// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @title _SMARTPausableLogic
/// @notice Base logic contract for SMARTPausable functionality.
/// @dev Contains validation hooks checking the paused state.
abstract contract _SMARTPausableLogic {
    // --- Custom Errors ---
    error TokenPaused();

    // --- Abstract Functions ---
    /// @dev Returns true if the contract is paused, and false otherwise.
    ///      Must be implemented by the concrete contract (usually via inheriting Pausable/PausableUpgradeable).
    function paused() public view virtual returns (bool);

    // --- Internal Hook Overrides (Base Implementation) ---
    // REMOVED - Concrete contracts (SMARTPausable, SMARTPausableUpgradeable)
    // will implement these checks directly using paused() before calling super.

    // function _validateMint(address /* to */, uint256 /* amount */) internal /* view */ virtual { ... }
    // function _validateTransfer(address /* from */, address /* to */, uint256 /* amount */) internal /* view */
    // virtual { ... }

    // Note: _validateBurn could also be added here if needed, but is not in the original SMARTPausable.sol

    // --- Internal Hook Logic Helper Functions ---

    // Renamed to include prefix
    function _pausable_validateMintLogic() internal view virtual {
        if (paused()) revert TokenPaused();
    }

    // Renamed to include prefix
    function _pausable_validateTransferLogic() internal view virtual {
        if (paused()) revert TokenPaused();
    }
}
