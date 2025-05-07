// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// -- Events --
/// @notice Emitted when an address's full frozen status is changed.
/// @param initiator The address that initiated the freeze operation.
/// @param userAddress The address whose status changed.
/// @param isFrozen The new frozen status (true if frozen, false if unfrozen).
event AddressFrozen(address indexed initiator, address indexed userAddress, bool indexed isFrozen);

/// @notice Emitted when assets are successfully recovered from a lost wallet to a new one.
/// @param initiator The address that initiated the freeze operation.
/// @param lostWallet The address from which assets were recovered.
/// @param newWallet The address to which assets were transferred.
/// @param investorOnchainID The on-chain ID associated with the investor.
event RecoverySuccess(
    address indexed initiator, address indexed lostWallet, address indexed newWallet, address investorOnchainID
);

/// @notice Emitted when a specific amount of tokens is frozen for an address.
/// @param initiator The address that initiated the freeze operation.
/// @param user The address for which tokens were frozen.
/// @param amount The amount of tokens frozen.
event TokensFrozen(address indexed initiator, address indexed user, uint256 amount);

/// @notice Emitted when a specific amount of tokens is unfrozen for an address.
/// @param initiator The address that initiated the freeze operation.
/// @param user The address for which tokens were unfrozen.
/// @param amount The amount of tokens unfrozen.
event TokensUnfrozen(address indexed initiator, address indexed user, uint256 amount);
