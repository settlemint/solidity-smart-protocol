// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

/// @title Internal Authorization Hooks for SMART Pausable Extension
/// @notice Defines internal hooks used by _SMARTPausableLogic to authorize pausing/unpausing.
/// @dev This contract is intended to be inherited by specific authorization implementations.
abstract contract _SMARTPausableAuthorizationHooks {
    /// @dev Hook to authorize pausing or unpausing the contract.
    function _authorizePause() internal view virtual;
}
