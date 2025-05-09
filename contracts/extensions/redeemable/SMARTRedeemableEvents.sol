// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// -- Events --

/// @notice Emitted when tokens are successfully redeemed (burned by the holder).
/// @param initiator The address redeeming the tokens.
/// @param amount The amount of tokens redeemed.
event Redeemed(address indexed initiator, uint256 amount);
