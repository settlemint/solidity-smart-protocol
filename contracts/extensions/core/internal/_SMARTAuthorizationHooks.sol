// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @title Internal Authorization Hooks for Core SMART Functionality
/// @notice Defines internal hooks used by _SMARTLogic to authorize state-changing operations.
/// @dev This contract is intended to be inherited by specific authorization implementations (e.g.,
/// AccessControl-based).
abstract contract _SMARTAuthorizationHooks {
    /// @dev Hook to authorize updating general token settings (name, symbol, onchainID).
    function _authorizeUpdateTokenSettings() internal view virtual;

    /// @dev Hook to authorize updating compliance settings (compliance contract, modules, parameters).
    function _authorizeUpdateComplianceSettings() internal view virtual;

    /// @dev Hook to authorize updating verification settings (identity registry, required claim topics).
    function _authorizeUpdateVerificationSettings() internal view virtual;

    /// @dev Hook to authorize minting new tokens.
    function _authorizeMintToken() internal view virtual;

    /// @dev Hook to authorize recovering mistakenly sent ERC20 tokens from the contract.
    function _authorizeRecoverERC20() internal view virtual;
}
