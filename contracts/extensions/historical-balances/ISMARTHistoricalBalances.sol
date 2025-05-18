// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Interface for SMART Historical Balances Extension
/// @notice Defines the external functions for querying historical token balances and total supply.
/// @dev This interface allows other contracts or off-chain applications to retrieve the balance of an account
///      or the total supply of the token at a specific past timepoint (e.g., block number).
///      A Solidity 'interface' is a contract blueprint that only declares function signatures without providing
///      their implementation. Contracts that 'implement' this interface must provide the defined functions.
interface ISMARTHistoricalBalances {
    /**
     * @notice Returns the token balance of a specific `account` at a given `timepoint`.
     * @dev The `timepoint` usually refers to a block number in the past. Implementations should revert
     *      if a `timepoint` in the future (or the current timepoint) is queried.
     *      `view` functions do not modify state and do not consume gas when called externally.
     * @param account The address of the account whose historical balance is being queried.
     * @param timepoint The specific past timepoint (e.g., block number) to retrieve the balance for.
     * @return uint256 The token balance of `account` at the specified `timepoint`.
     */
    function balanceOfAt(address account, uint256 timepoint) external view returns (uint256);

    /**
     * @notice Returns the total token supply at a given `timepoint`.
     * @dev Similar to `balanceOfAt`, `timepoint` refers to a past block number. Implementations should
     *      revert for future or current timepoints.
     * @param timepoint The specific past timepoint (e.g., block number) to retrieve the total supply for.
     * @return uint256 The total token supply at the specified `timepoint`.
     */
    function totalSupplyAt(uint256 timepoint) external view returns (uint256);
}
