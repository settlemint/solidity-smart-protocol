// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Interface for the SMART Capped Extension
/// @notice Defines the external functions for interacting with the SMART Capped extension.
interface ISMARTCapped {
    /// @notice Returns the cap on the token's total supply.
    /// @return The maximum allowed total supply.
    function cap() external view returns (uint256);
}
