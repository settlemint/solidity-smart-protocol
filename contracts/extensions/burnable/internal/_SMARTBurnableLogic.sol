// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { LengthMismatch } from "../../common/CommonErrors.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";
import { BurnCompleted } from "./../SMARTBurnableEvents.sol";
import { ISMARTBurnable } from "./../ISMARTBurnable.sol";

/// @title Internal Logic for SMART Burnable Extension
/// @notice Contains the core internal logic and event for burning tokens.
/// @dev This contract provides the `burn` and `batchBurn` functions and defines
///      abstract hooks for authorization and execution.

abstract contract _SMARTBurnableLogic is _SMARTExtension, ISMARTBurnable {
    // -- Internal Setup Function --
    function __SMARTBurnable_init_unchained() internal {
        _registerInterface(type(ISMARTBurnable).interfaceId);
    }

    // -- Abstract Functions (Dependencies) --

    /// @dev Abstract function representing the actual token burning mechanism.
    ///      Must be implemented by inheriting contracts to interact with the base token contract (e.g.,
    /// ERC20/ERC20Upgradeable).
    /// @param from The address from which tokens are burned.
    /// @param amount The amount of tokens to burn.
    function __burnable_executeBurn(address from, uint256 amount) internal virtual;

    // -- Internal Implementation for ISMARTBurnable Interface Functions --

    /// @dev Internal function to perform the burn operation after authorization.
    /// @param userAddress The address from which tokens are burned.
    /// @param amount The amount of tokens to burn.
    function _smart_burn(address userAddress, uint256 amount) internal virtual {
        __burnable_burnLogic(userAddress, amount);
    }

    /// @dev Internal function to perform a batch burn operation after authorization.
    /// @param userAddresses The addresses from which tokens are burned.
    /// @param amounts The amounts of tokens to burn from each address.
    function _smart_batchBurn(address[] calldata userAddresses, uint256[] calldata amounts) internal virtual {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        uint256 length = userAddresses.length;
        for (uint256 i = 0; i < length; ++i) {
            __burnable_burnLogic(userAddresses[i], amounts[i]);
        }
    }

    // -- Internal Functions --

    /// @dev Internal function to perform the burn operation after authorization.
    function __burnable_burnLogic(address from, uint256 amount) private {
        __burnable_executeBurn(from, amount); // Execute the burn
        emit BurnCompleted(_smartSender(), from, amount); // Emit event
    }
}
