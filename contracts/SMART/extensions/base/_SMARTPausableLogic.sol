// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @title _SMARTPausableLogic
/// @notice Base logic contract for SMARTPausable functionality.
/// @dev Contains validation hooks checking the paused state.
abstract contract _SMARTPausableLogic {
    // --- Errors ---
    error TokenPaused();

    // --- Abstract Functions ---
    /// @dev Returns true if the contract is paused, and false otherwise.
    ///      Must be implemented by the concrete contract (usually via inheriting Pausable/PausableUpgradeable).
    function paused() public view virtual returns (bool);

    // --- Internal Functions ---
    // Hook Helper Functions
    function _pausable_beforeMintLogic() internal view virtual {
        if (paused()) revert TokenPaused();
    }

    function _pausable_beforeTransferLogic() internal view virtual {
        if (paused()) revert TokenPaused();
    }

    function _pausable_beforeBurnLogic() internal view virtual {
        if (paused()) revert TokenPaused();
    }
}
