// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/**
 * @dev Error thrown when attempting to query a balance or total supply at a timepoint in the future.
 * @param requestedTimepoint The future timepoint (e.g., block number) that was requested.
 * @param currentTimepoint The current timepoint (e.g., current block number) according to the `clock()`.
 */
error FutureLookup(uint256 requestedTimepoint, uint48 currentTimepoint);
