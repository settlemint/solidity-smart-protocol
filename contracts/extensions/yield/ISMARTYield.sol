// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISMARTHistoricalBalances } from "./../historical-balances/ISMARTHistoricalBalances.sol";

interface ISMARTYield is ISMARTHistoricalBalances {
    /// @notice Sets the yield schedule for this token
    /// @dev Override this function to add additional access control if needed
    /// @param schedule The address of the yield schedule contract
    function setYieldSchedule(address schedule) external;

    /// @notice Returns the basis amount used to calculate yield per token unit
    /// @dev Override this function to define the yield calculation basis. For example, face value for bonds or token
    /// value for shares
    /// @param holder The address to get the yield basis for, allowing for holder-specific basis amounts
    /// @return The basis amount per token unit used in yield calculations
    function yieldBasisPerUnit(address holder) external view returns (uint256);

    /// @notice Returns the token used for yield payments
    /// @dev Override this function to specify which token is used for yield payments
    /// @return The token used for yield payments
    function yieldToken() external view returns (IERC20);

    /// @notice Checks if an address can manage yield on this token
    /// @dev Override this function to implement permission checks
    /// @param manager The address to check
    /// @return True if the address can manage yield
    function canManageYield(address manager) external view returns (bool);
}
