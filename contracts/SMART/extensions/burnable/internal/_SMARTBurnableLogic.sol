// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { LengthMismatch, Unauthorized } from "../../common/CommonErrors.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";
import { _SMARTBurnableAuthorizationHooks } from "./_SMARTBurnableAuthorizationHooks.sol";
/// @title _SMARTBurnableLogic
/// @notice Base logic contract for SMARTBurnable functionality.
/// @dev Contains internal implementations for burning tokens.

abstract contract _SMARTBurnableLogic is _SMARTExtension, _SMARTBurnableAuthorizationHooks {
    // --- Abstract Hooks ---

    /// @dev Abstract function representing the actual burn operation (e.g., ERC20Burnable._burn).
    ///      This needs to be implemented in the concrete contract inheriting this logic
    ///      and ERC20Burnable(Upgradeable).
    function _burnable_executeBurn(address from, uint256 amount) internal virtual;

    // --- Internal Functions ---

    /// @dev Internal implementation for burning a specific amount of tokens.
    ///      Relies on concrete contract providing `_beforeBurn`, `_burn`, `_afterBurn`.
    function _burnInternal(address userAddress, uint256 amount) internal virtual {
        _authorizeBurn();
        _beforeBurn(userAddress, amount);
        // We cannot call _burn directly here, hence _executeBurn.
        _burnable_executeBurn(userAddress, amount);
        _afterBurn(userAddress, amount);
    }

    /// @dev Internal implementation for burning tokens from multiple addresses.
    function _batchBurnInternal(address[] calldata userAddresses, uint256[] calldata amounts) internal virtual {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _burnInternal(userAddresses[i], amounts[i]);
        }
    }
}
