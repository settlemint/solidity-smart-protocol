// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { _SMARTExtension } from "../../common/_SMARTExtension.sol";
import { TokenPaused, ExpectedPause } from "./../SMARTPausableErrors.sol";
import { Paused, Unpaused } from "./../SMARTPausableEvents.sol";
import { ISMARTPausable } from "./../ISMARTPausable.sol";
/// @title Internal Logic for SMART Pausable Extension
/// @notice Base contract containing the core state, logic, events, and authorization hooks for pausable features.
/// @dev This abstract contract handles the `_paused` state, provides `pause`/`unpause` functions (with authorization
/// checks),
///      and defines modifiers (`whenNotPaused`, `whenPaused`). It inherits authorization hooks.

abstract contract _SMARTPausableLogic is _SMARTExtension, ISMARTPausable {
    // -- State Variables --
    /// @notice Internal flag indicating whether the contract is paused.
    bool private _paused;

    // -- Internal Setup Function --
    function __SMARTPausable_init_unchained() internal {
        _registerInterface(type(ISMARTPausable).interfaceId);
    }

    // -- View Functions --

    /// @inheritdoc ISMARTPausable
    function paused() public view virtual override returns (bool) {
        return _paused;
    }

    // -- State-Changing Functions (Admin/Authorized) --

    /// @dev Internal function to pause the contract.
    function _smart_pause() internal virtual {
        if (_paused) revert ExpectedPause(); // Should be ExpectedUnpause, or use a specific error
        _paused = true;
        emit Paused(_smartSender()); // Use _msgSender() from context if available, else pass msg.sender
    }

    /// @dev Internal function to unpause the contract.
    function _smart_unpause() internal virtual {
        if (!_paused) revert TokenPaused(); // Should be ExpectedPause, or use a specific error
        _paused = false;
        emit Unpaused(_smartSender()); // Use _msgSender() from context if available, else pass msg.sender
    }

    // -- Modifiers --

    /// @dev Modifier to make a function callable only when the contract is not paused.
    ///      Reverts with `TokenPaused` error if called while paused.
    modifier whenNotPaused() {
        if (paused()) {
            revert TokenPaused();
        }
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused.
    ///      Reverts with `ExpectedPause` error if called while not paused.
    modifier whenPaused() {
        if (!paused()) {
            revert ExpectedPause();
        }
        _;
    }
}
