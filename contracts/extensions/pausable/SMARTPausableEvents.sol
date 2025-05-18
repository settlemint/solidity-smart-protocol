// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Events for SMART Pausable Extension
/// @notice Defines events emitted when the contract's paused state is changed.
/// @dev Events are crucial for off-chain applications to track and react to on-chain state changes.
///      Listening for `Paused` and `Unpaused` events allows UIs, monitoring tools, or other services
///      to know when token operations are halted or resumed.

// -- Events --
/// @notice Emitted when the contract transitions to a paused state.
/// @dev This event signals that standard operations (like transfers) are likely now blocked.
/// @param sender The address that initiated the `pause` operation. This is typically an authorized
///               account with a PAUSER_ROLE. `indexed` for easier filtering of events initiated
///               by a specific admin or pauser address.
event Paused(address indexed sender);

/// @notice Emitted when the contract transitions out of a paused state (i.e., is unpaused).
/// @dev This event signals that standard operations are likely resumed.
/// @param sender The address that initiated the `unpause` operation. Similar to `Paused` event, this is
///               typically an authorized account. `indexed` for filtering.
event Unpaused(address indexed sender);
