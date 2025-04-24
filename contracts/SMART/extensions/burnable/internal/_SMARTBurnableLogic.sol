// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { LengthMismatch } from "../../common/CommonErrors.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";
import { _SMARTBurnableAuthorizationHooks } from "./_SMARTBurnableAuthorizationHooks.sol";
/// @title _SMARTBurnableLogic
/// @notice Base logic contract for SMARTBurnable functionality.
/// @dev Contains internal implementations for burning tokens.

abstract contract _SMARTBurnableLogic is _SMARTExtension, _SMARTBurnableAuthorizationHooks {
    // --- State-Changing Functions ---

    // -- Events --
    event BurnCompleted(address indexed from, uint256 amount);

    // @notice Burns a specific amount of tokens from a user's address (Owner only).
    /// @param userAddress The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    /// @dev Requires caller to be the owner. Matches IERC3643 signature.
    function burn(address userAddress, uint256 amount) external virtual {
        __burnable_burn(userAddress, amount);
    }

    /// @notice Burns tokens from multiple addresses in a single transaction (Owner only).
    /// @param userAddresses The addresses to burn tokens from.
    /// @param amounts The amounts of tokens to burn from each address.
    /// @dev Requires caller to be the owner.
    function batchBurn(address[] calldata userAddresses, uint256[] calldata amounts) public virtual {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            __burnable_burn(userAddresses[i], amounts[i]);
        }
    }

    // --- Abstract Hooks ---

    /// @dev Abstract function representing the actual burn operation (e.g., ERC20Burnable._burn).
    ///      This needs to be implemented in the concrete contract inheriting this logic
    ///      and ERC20Burnable(Upgradeable).
    function _burnable_executeBurn(address from, uint256 amount) internal virtual;

    function __burnable_burn(address from, uint256 amount) internal virtual {
        _authorizeBurn();
        _burnable_executeBurn(from, amount);
        emit BurnCompleted(from, amount);
    }
}
