// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @notice Error thrown when an operation would cause the total supply to exceed the defined cap.
/// @param newSupply The total supply that would result from the operation.
/// @param cap The maximum allowed total supply.
error SMARTExceededCap(uint256 newSupply, uint256 cap);

/// @notice Error thrown if an invalid cap value (e.g., 0) is provided during initialization.
/// @param cap The invalid cap value provided.
error SMARTInvalidCap(uint256 cap);
