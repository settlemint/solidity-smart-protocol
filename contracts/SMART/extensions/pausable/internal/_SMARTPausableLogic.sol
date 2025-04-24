// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { _SMARTPausableAuthorizationHooks } from "./_SMARTPausableAuthorizationHooks.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";

/// @title _SMARTPausableLogic
/// @notice Base logic contract for SMARTPausable functionality.
/// @dev Contains validation hooks checking the paused state.
abstract contract _SMARTPausableLogic is _SMARTExtension, _SMARTPausableAuthorizationHooks {
    // --- State-Changing Functions ---
    /// @notice Pauses the contract (Owner only).
    function pause() public virtual {
        _authorizePause();
        _pausable_executePause();
    }

    /// @notice Unpauses the contract (Owner only).
    function unpause() public virtual {
        _authorizePause();
        _pausable_executeUnpause();
    }

    // --- Abstract Functions ---
    /// @dev Returns true if the contract is paused, and false otherwise.
    ///      Must be implemented by the concrete contract (usually via inheriting Pausable/PausableUpgradeable).
    function paused() public view virtual returns (bool);

    function _pausable_executePause() internal virtual;

    function _pausable_executeUnpause() internal virtual;

    // --- Internal Functions ---
}
