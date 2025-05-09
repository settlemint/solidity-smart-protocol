// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTBurnable {
    /// @notice Burns a specific amount of tokens from a user's address.
    /// @param userAddress The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    /// @dev Requires authorization via the `_authorizeBurn` hook.
    ///      Matches the function signature intent of ERC3643 `operatorBurn`.
    function burn(address userAddress, uint256 amount) external;

    /// @notice Burns tokens from multiple addresses in a single transaction.
    /// @param userAddresses The addresses to burn tokens from.
    /// @param amounts The amounts of tokens to burn from each address.
    /// @dev Requires authorization via the `_authorizeBurn` hook for each burn.
    ///      Reverts if the lengths of `userAddresses` and `amounts` do not match.
    function batchBurn(address[] calldata userAddresses, uint256[] calldata amounts) external;
}
