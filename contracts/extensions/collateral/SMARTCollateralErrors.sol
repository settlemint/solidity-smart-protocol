// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

/// @notice Reverts if the required total supply (current + minted amount) exceeds the collateral amount found in a
/// valid claim.
/// @param required The total supply required after minting.
/// @param available The collateral amount available according to the valid claim.
error InsufficientCollateral(uint256 required, uint256 available);

/// @notice Reverts if the provided collateral proof topic ID is invalid during initialization (e.g., 0).
/// @param topicId The invalid topic ID provided.
error InvalidCollateralTopic(uint256 topicId);
