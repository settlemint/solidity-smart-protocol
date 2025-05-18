// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Interface for SMART Token Burning Operations
/// @notice This interface defines the functions that a contract must implement to allow
///         for the burning (destruction) of SMART tokens. Adhering to this interface
///         ensures that other contracts or systems can interact with any burnable SMART token
///         in a standardized way.
///         In Solidity, an interface is like a contract's public face: it lists the functions
///         that can be called, their parameters, and what they return, but not how they work internally.
interface ISMARTBurnable {
    /// @notice Burns (destroys) a specific amount of tokens from a given user's address.
    /// @dev This function is intended for an authorized operator (like an admin or a special role)
    ///      to burn tokens on behalf of a user, or from a specific account as part of token management.
    ///      The actual authorization logic (who can call this) is typically handled by the contract
    ///      implementing this interface, often through a mechanism like an `_authorizeBurn` hook.
    ///      The function signature and intent are similar to `operatorBurn` as suggested by standards
    ///      like ERC3643, where an operator can manage token holdings.
    /// @param userAddress The blockchain address of the account from which tokens will be burned.
    ///                    This is the account whose token balance will decrease.
    /// @param amount The quantity of tokens to burn. This should be a non-negative integer.
    function burn(address userAddress, uint256 amount) external;

    /// @notice Burns (destroys) tokens from multiple user addresses in a single transaction.
    /// @dev This function allows for efficient batch processing of token burns, which can save on
    ///      transaction fees (gas) compared to calling `burn` multiple times individually.
    ///      It requires that the `userAddresses` array and the `amounts` array have the same number of elements,
    ///      with each `amounts[i]` corresponding to `userAddresses[i]`.
    ///      Similar to the single `burn` function, authorization for each individual burn within the batch
    ///      is expected to be handled by the implementing contract (e.g., via an `_authorizeBurn` hook).
    ///      If the lengths of the input arrays do not match, the transaction should revert to prevent errors.
    /// @param userAddresses An array of blockchain addresses from which tokens will be burned.
    /// @param amounts An array of token quantities to be burned. `amounts[i]` tokens will be burned
    ///                from `userAddresses[i]`.
    function batchBurn(address[] calldata userAddresses, uint256[] calldata amounts) external;
}
