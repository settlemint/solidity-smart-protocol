// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

interface ISMARTHistoricalBalances {
    function balanceOfAt(address account, uint256 timepoint) external view returns (uint256);
    function totalSupplyAt(uint256 timepoint) external view returns (uint256);
}
