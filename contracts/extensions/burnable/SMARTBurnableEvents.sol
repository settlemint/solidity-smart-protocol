// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @notice Emitted when tokens are successfully burned.
/// @param initiator The address that initiated the burn operation.
/// @param from The address from which tokens were burned.
/// @param amount The amount of tokens burned.
event BurnCompleted(address indexed initiator, address indexed from, uint256 amount);
