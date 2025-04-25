// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { _SMARTPausableAuthorizationHooks } from "./_SMARTPausableAuthorizationHooks.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";
import { TokenPaused, ExpectedPause } from "./../SMARTPausableErrors.sol";

/// @title Internal Logic for SMART Pausable Extension
/// @notice Base contract containing the core state, logic, events, and authorization hooks for pausable features.
/// @dev This abstract contract handles the `_paused` state, provides `pause`/`unpause` functions (with authorization
/// checks),
///      and defines modifiers (`whenNotPaused`, `whenPaused`). It inherits authorization hooks.
abstract contract _SMARTPausableLogic is _SMARTExtension, _SMARTPausableAuthorizationHooks {
    // -- State Variables --
    /// @notice Internal flag indicating whether the contract is paused.
    bool private _paused;

    // -- Events --
    /// @notice Emitted when the contract is paused.
    /// @param account The address that triggered the pause.
    event Paused(address account);
    /// @notice Emitted when the contract is unpaused.
    /// @param account The address that triggered the unpause.
    event Unpaused(address account);

    // -- View Functions --

    /// @notice Returns true if the contract is paused, false otherwise.
    function paused() public view returns (bool) {
        return _paused;
    }

    // -- State-Changing Functions (Admin/Authorized) --

    /// @notice Pauses the contract, preventing certain actions (e.g., transfers).
    /// @dev Requires authorization via `_authorizePause`. Reverts if already paused.
    function pause() external {
        _authorizePause();
        if (_paused) revert ExpectedPause(); // Should be ExpectedUnpause, or use a specific error
        _paused = true;
        emit Paused(_msgSender()); // Use _msgSender() from context if available, else pass msg.sender
    }

    /// @notice Unpauses the contract, resuming normal operations.
    /// @dev Requires authorization via `_authorizePause`. Reverts if not paused.
    function unpause() external {
        _authorizePause();
        if (!_paused) revert TokenPaused(); // Should be ExpectedPause, or use a specific error
        _paused = false;
        emit Unpaused(_msgSender()); // Use _msgSender() from context if available, else pass msg.sender
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

    // -- Abstract Dependencies --
    // Assuming _msgSender() is provided by an inheriting contract (like AccessControl or Context)
    function _msgSender() internal view virtual returns (address);
}
