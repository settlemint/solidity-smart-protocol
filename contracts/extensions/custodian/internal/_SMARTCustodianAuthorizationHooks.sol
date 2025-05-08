// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

/// @title Internal Authorization Hooks for SMART Custodian Extension
/// @notice Defines internal hooks used by _SMARTCustodianLogic to authorize custodian operations.
/// @dev This contract is intended to be inherited by specific authorization implementations.
abstract contract _SMARTCustodianAuthorizationHooks {
    /// @dev Hook to authorize freezing or unfreezing an entire address.
    function _authorizeFreezeAddress() internal view virtual;

    /// @dev Hook to authorize freezing or unfreezing a partial amount of tokens for an address.
    function _authorizeFreezePartialTokens() internal view virtual;

    /// @dev Hook to authorize forced transfer operations.
    function _authorizeForcedTransfer() internal view virtual;

    /// @dev Hook to authorize address recovery operations.
    function _authorizeRecoveryAddress() internal view virtual;
}
