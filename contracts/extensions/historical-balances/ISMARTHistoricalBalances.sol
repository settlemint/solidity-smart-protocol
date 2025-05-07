// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

interface ISMARTHistoricalBalances {
    function balanceOfAt(address account, uint256 timepoint) external view returns (uint256);
    function totalSupplyAt(uint256 timepoint) external view returns (uint256);
}
