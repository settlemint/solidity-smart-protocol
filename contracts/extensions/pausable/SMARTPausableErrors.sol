// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

/// @notice Error reverted when an action requiring an unpaused state is attempted while the contract is paused.
error TokenPaused();
/// @notice Error reverted when an action requiring a paused state is attempted while the contract is not paused.
error ExpectedPause();
