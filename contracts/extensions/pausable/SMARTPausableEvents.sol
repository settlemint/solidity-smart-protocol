// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// -- Events --
/// @notice Emitted when the contract is paused.
/// @param initiator The address that triggered the pause.
event Paused(address indexed initiator);

/// @notice Emitted when the contract is unpaused.
/// @param initiator The address that triggered the unpause.
event Unpaused(address indexed initiator);
