// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @dev Error triggered when batch operation arrays have different lengths.
error LengthMismatch();
/// @notice The caller is not authorized to perform the action.
error Unauthorized(address account);
/// @notice The provided address is a zero address.
error ZeroAddressNotAllowed();
