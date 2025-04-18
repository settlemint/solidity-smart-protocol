// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { LengthMismatch } from "../common/CommonErrors.sol";

/// @title _SMARTBurnableLogic
/// @notice Base logic contract for SMARTBurnable functionality.
/// @dev Contains internal implementations for burning tokens.
abstract contract _SMARTBurnableLogic {
    // --- Internal Burn Logic ---
    // Concrete contracts will call these internal functions,
    // potentially wrapping them with access control (e.g., onlyOwner).

    /// @dev Internal implementation for burning a specific amount of tokens.
    ///      Relies on concrete contract providing `_validateBurn`, `_burn`, `_afterBurn`
    ///      (likely inherited from SMARTExtension and ERC20Burnable/Upgradeable).
    function _burnInternal(address userAddress, uint256 amount) internal virtual {
        _validateBurn(userAddress, amount);
        // Call the actual burn function provided by ERC20Burnable(Upgradeable)
        // This needs to be implemented in the concrete contract inheriting this logic
        // and ERC20Burnable(Upgradeable). We cannot call _burn directly here.
        _executeBurn(userAddress, amount);
        _afterBurn(userAddress, amount);
    }

    /// @dev Internal implementation for burning tokens from multiple addresses.
    function _batchBurnInternal(address[] calldata userAddresses, uint256[] calldata amounts) internal virtual {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            // Call the single internal burn implementation
            _burnInternal(userAddresses[i], amounts[i]);
        }
    }

    // --- Abstract Hooks ---
    // These must be implemented by the concrete contract, typically by inheriting
    // SMARTExtension(Upgradeable) and ERC20Burnable(Upgradeable).

    /// @dev Abstract internal validation hook for burning tokens.
    function _validateBurn(address from, uint256 amount) internal virtual;

    /// @dev Abstract internal hook called after burning tokens.
    function _afterBurn(address from, uint256 amount) internal virtual;

    /// @dev Abstract function representing the actual burn operation (e.g., ERC20Burnable._burn).
    function _executeBurn(address from, uint256 amount) internal virtual;
}
