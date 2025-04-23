// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

abstract contract _SMARTCustodianAuthorizationHooks {
    /// @notice Authorization hook for freezing an address
    /// @return Whether the freeze operation is authorized
    function _authorizeFreezeAddress() internal view virtual returns (bool);

    /// @notice Authorization hook for freezing partial tokens
    /// @return Whether the freeze operation is authorized
    function _authorizeFreezePartialTokens() internal view virtual returns (bool);

    /// @notice Authorization hook for forced transfer operations
    /// @return Whether the forced transfer operation is authorized
    function _authorizeForcedTransfer() internal view virtual returns (bool);

    /// @notice Authorization hook for address recovery operations

    /// @return Whether the recovery operation is authorized
    function _authorizeRecoveryAddress() internal view virtual returns (bool);
}
