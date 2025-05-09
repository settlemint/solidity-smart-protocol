// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTPausable {
    // -- View Functions --

    /// @notice Returns true if the contract is paused, false otherwise.
    function paused() external view returns (bool);

    // -- State-Changing Functions (Admin/Authorized) --

    /// @notice Pauses the contract, preventing certain actions (e.g., transfers).
    /// @dev Requires authorization via `_authorizePause`. Reverts if already paused.
    function pause() external;

    /// @notice Unpauses the contract, resuming normal operations.
    /// @dev Requires authorization via `_authorizePause`. Reverts if not paused.
    function unpause() external;
}
