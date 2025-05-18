// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Events for SMART Core Extension
/// @notice Defines events emitted by the SMART core token logic.
/// @dev Events are a way for smart contracts to log significant occurrences on the blockchain.
///      Off-chain applications can listen for these events to track contract activity, update user interfaces,
///      or trigger other processes. `indexed` parameters in events allow for more efficient searching and filtering
///      of these logs by off-chain applications.

/// @notice Emitted when mistakenly sent ERC20 tokens are recovered from the contract.
/// @param sender The address that initiated the recovery operation. `indexed` for easier filtering.
/// @param token The address of the ERC20 token recovered. `indexed` for easier filtering.
/// @param to The address to which the tokens were recovered. `indexed` for easier filtering.
/// @param amount The amount of tokens recovered.
event TokenRecovered(address indexed sender, address indexed token, address indexed to, uint256 amount);
