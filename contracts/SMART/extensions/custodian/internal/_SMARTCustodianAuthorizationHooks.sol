// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

abstract contract _SMARTCustodianAuthorizationHooks {
    /// @notice Authorization hook for freezing an address
    function _authorizeFreezeAddress() internal view virtual;

    /// @notice Authorization hook for freezing partial tokens
    function _authorizeFreezePartialTokens() internal view virtual;

    /// @notice Authorization hook for forced transfer operations
    function _authorizeForcedTransfer() internal view virtual;

    /// @notice Authorization hook for address recovery operations

    function _authorizeRecoveryAddress() internal view virtual;
}
