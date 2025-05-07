// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

/// @dev Error triggered when batch operation arrays have different lengths.
error LengthMismatch();
/// @notice The caller is not authorized to perform the action.
error Unauthorized(address account);
/// @notice The provided address is a zero address.
error ZeroAddressNotAllowed();
