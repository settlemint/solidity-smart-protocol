    // SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

/// @notice Emitted when mistakenly sent ERC20 tokens are recovered from the contract.
event TokenRecovered(address indexed token, address indexed to, uint256 amount);
