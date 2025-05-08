    // SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @notice Emitted when mistakenly sent ERC20 tokens are recovered from the contract.
/// @param initiator The address that initiated the recovery operation.
/// @param token The address of the ERC20 token recovered.
/// @param to The address to which the tokens were recovered.
/// @param amount The amount of tokens recovered.
event TokenRecovered(address indexed initiator, address indexed token, address indexed to, uint256 amount);
