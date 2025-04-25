// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @notice Error reverted when an action requiring an unpaused state is attempted while the contract is paused.
error TokenPaused();
/// @notice Error reverted when an action requiring a paused state is attempted while the contract is not paused.
error ExpectedPause();
