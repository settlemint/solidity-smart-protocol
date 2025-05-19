// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Interface for SMART Pausable Extension
/// @notice Defines the external functions for a pausable SMART token.
/// @dev This interface outlines the standard functions for pausing, unpausing, and checking the paused
///      state of a contract. Implementations of this interface are expected to restrict the `pause` and
///      `unpause` functions to authorized addresses (e.g., an address with a PAUSER_ROLE).
///      A Solidity 'interface' is a contract blueprint: it declares functions (name, parameters, visibility,
///      return types) but doesn't implement them. Other contracts implement interfaces to guarantee they
///      provide specific functionalities, promoting interoperability.
interface ISMARTPausable {
    // -- View Functions --

    /// @notice Returns `true` if the contract is currently paused, and `false` otherwise.
    /// @dev This is a `view` function, meaning it does not modify the blockchain state and does not
    ///      cost gas when called externally (e.g., from an off-chain script or another contract's view function).
    /// @return bool The current paused state of the contract.
    function paused() external view returns (bool);

    // -- State-Changing Functions (Admin/Authorized) --

    /// @notice Pauses the contract, which typically prevents certain actions like token transfers.
    /// @dev Implementations should ensure this function can only be called by an authorized address
    ///      (e.g., through a modifier like `onlyPauser`). It should revert if the contract is already paused
    ///      to prevent redundant operations or event emissions.
    function pause() external;

    /// @notice Unpauses the contract, resuming normal operations (e.g., allowing token transfers again).
    /// @dev Similar to `pause()`, this function should be restricted to authorized addresses and should
    ///      revert if the contract is not currently paused.
    function unpause() external;
}
