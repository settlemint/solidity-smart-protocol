// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Events for SMART Historical Balances Extension
/// @notice Defines events related to the creation of balance and total supply checkpoints.
/// @dev Events are useful for off-chain applications to track when historical data points are recorded.

/**
 * @notice Emitted when a new checkpoint is written for an account's balance or for the total supply
 *         due to a token operation (mint, burn, transfer).
 * @dev This event signals that a historical data point has been recorded.
 *      Off-chain services can listen to this event to know when to update their own historical data caches
 *      or to trigger other actions based on balance changes.
 * @param sender The address that initiated the token operation (e.g., minter, transferer, burner)
 *               which resulted in this checkpoint update. `indexed` for easier filtering.
 * @param account The address for which a balance checkpoint was created. If this is `address(0)`,
 *                it signifies that the checkpoint is for the token's `totalSupply`.
 *                `indexed` for tracking specific accounts or total supply updates.
 * @param oldBalance The balance (either of `account` or `totalSupply`) *before* the operation that triggered
 *                   the checkpoint.
 * @param newBalance The balance (either of `account` or `totalSupply`) *after* the operation and at the
 *                   time of this checkpoint.
 */
event CheckpointUpdated(address indexed sender, address indexed account, uint256 oldBalance, uint256 newBalance);
