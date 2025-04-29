    // SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @notice Emitted when mistakenly sent ERC20 tokens are recovered from the contract.
event TokenRecovered(address indexed token, address indexed to, uint256 amount);
