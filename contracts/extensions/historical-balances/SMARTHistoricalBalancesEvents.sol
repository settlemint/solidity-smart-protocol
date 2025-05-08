// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/**
 * @dev Emitted when a balance checkpoint is created for an account or for the total supply.
 * @param initiator The address that initiated the checkpoint update.
 * @param account The account for which a balance checkpoint was created. If address(0), it's a total supply
 * checkpoint.
 * @param oldBalance The balance before the operation that triggered the checkpoint.
 * @param newBalance The balance after the operation that triggered the checkpoint.
 */
event CheckpointUpdated(address indexed initiator, address indexed account, uint256 oldBalance, uint256 newBalance);
