// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @title Internal Authorization Hooks for SMART Burnable Extension
/// @notice Defines internal hooks for authorizing burn operations.
/// @dev This contract is intended to be inherited by authorization implementations.
abstract contract _SMARTBurnableAuthorizationHooks {
    /// @dev Internal hook called before executing a burn operation.
    ///      Implementations should revert if the caller is not authorized.
    function _authorizeBurn() internal view virtual;
}
