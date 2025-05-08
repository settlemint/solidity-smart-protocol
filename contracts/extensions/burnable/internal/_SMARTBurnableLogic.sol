// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { LengthMismatch } from "../../common/CommonErrors.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";
import { _SMARTBurnableAuthorizationHooks } from "./_SMARTBurnableAuthorizationHooks.sol";
import { BurnCompleted } from "./../SMARTBurnableEvents.sol";
/// @title Internal Logic for SMART Burnable Extension
/// @notice Contains the core internal logic and event for burning tokens.
/// @dev This contract provides the `burn` and `batchBurn` functions and defines
///      abstract hooks for authorization and execution.

abstract contract _SMARTBurnableLogic is _SMARTExtension, _SMARTBurnableAuthorizationHooks {
    // -- External Functions --

    /// @notice Burns a specific amount of tokens from a user's address.
    /// @param userAddress The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    /// @dev Requires authorization via the `_authorizeBurn` hook.
    ///      Matches the function signature intent of ERC3643 `operatorBurn`.
    function burn(address userAddress, uint256 amount) external virtual {
        __burnable_burn(userAddress, amount);
    }

    /// @notice Burns tokens from multiple addresses in a single transaction.
    /// @param userAddresses The addresses to burn tokens from.
    /// @param amounts The amounts of tokens to burn from each address.
    /// @dev Requires authorization via the `_authorizeBurn` hook for each burn.
    ///      Reverts if the lengths of `userAddresses` and `amounts` do not match.
    function batchBurn(address[] calldata userAddresses, uint256[] calldata amounts) public virtual {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            __burnable_burn(userAddresses[i], amounts[i]);
        }
    }

    // -- Internal Functions --

    /// @dev Internal function to perform the burn operation after authorization.
    function __burnable_burn(address from, uint256 amount) private {
        _authorizeBurn(); // Authorization check
        _burnable_executeBurn(from, amount); // Execute the burn
        emit BurnCompleted(_smartSender(), from, amount); // Emit event
    }

    // -- Abstract Hooks --

    /// @dev Abstract function representing the actual token burning mechanism.
    ///      Must be implemented by inheriting contracts to interact with the base token contract (e.g.,
    /// ERC20/ERC20Upgradeable).
    /// @param from The address from which tokens are burned.
    /// @param amount The amount of tokens to burn.
    function _burnable_executeBurn(address from, uint256 amount) internal virtual;
}
