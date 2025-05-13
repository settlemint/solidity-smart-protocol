// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Interface for SMARTYieldManager contract
/// @notice Defines the functions needed for external interaction with YieldManager schedules
interface ISMARTYieldManager {
    /// @notice Returns the start date of the yield schedule
    function startDate() external view returns (uint256);
}
