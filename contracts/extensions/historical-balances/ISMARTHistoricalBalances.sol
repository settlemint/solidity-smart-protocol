// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTHistoricalBalances {
    /**
     * @dev Returns the token balance of a specific `account` at a given `timepoint`.
     * @param account The address of the account to query.
     * @param timepoint The timepoint (e.g., block number) at which to retrieve the balance.
     * @return The token balance of `account` at `timepoint`.
     */
    function balanceOfAt(address account, uint256 timepoint) external view returns (uint256);

    /**
     * @dev Returns the total token supply at a given `timepoint`.
     * @param timepoint The timepoint (e.g., block number) at which to retrieve the total supply.
     * @return The total token supply at `timepoint`.
     */
    function totalSupplyAt(uint256 timepoint) external view returns (uint256);
}
