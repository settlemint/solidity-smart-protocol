// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// Removed ERC20Burnable import - no longer inherited directly
// import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { SMARTExtension } from "./SMARTExtension.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LengthMismatch } from "./common/CommonErrors.sol";
import { _SMARTBurnableLogic } from "./base/_SMARTBurnableLogic.sol"; // Import base logic
import { SMARTHooks } from "./common/SMARTHooks.sol";
/// @title SMARTBurnable
/// @notice Standard (non-upgradeable) extension that adds burnable functionality to SMART tokens.
/// @dev Inherits from Ownable, SMARTExtension, and _SMARTBurnableLogic.
///      Relies on the main contract inheriting ERC20 to provide the internal _burn function.
/// @dev Does not inherit ERC20Burnable directly to avoid exposing public `burn(value)` and `burnFrom(account, value)`,
///      which conflict with the IERC3643 requirement for an owner-controlled `burn(address, amount)` function.

abstract contract SMARTBurnable is
    SMARTExtension,
    Ownable,
    _SMARTBurnableLogic // Inherit base logic
{
    // No constructor needed unless initialization is required

    // --- State-Changing Functions ---

    /// @notice Burns a specific amount of tokens from a user's address (Owner only).
    /// @param userAddress The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    /// @dev Requires caller to be the owner. Matches IERC3643 signature.
    function burn(address userAddress, uint256 amount) public virtual onlyOwner {
        _burnInternal(userAddress, amount); // Calls base logic
    }

    /// @notice Burns tokens from multiple addresses in a single transaction (Owner only).
    /// @param userAddresses The addresses to burn tokens from.
    /// @param amounts The amounts of tokens to burn from each address.
    /// @dev Requires caller to be the owner.
    function batchBurn(address[] calldata userAddresses, uint256[] calldata amounts) public virtual onlyOwner {
        _batchBurnInternal(userAddresses, amounts); // Calls base logic
    }

    // --- Hooks ---

    /// @dev Internal validation hook for burning tokens.
    function _beforeBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        // Add any burnable-specific validation here if needed
        super._beforeBurn(from, amount); // Call downstream validation
    }

    /// @dev Internal hook called after burning tokens.
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        // Add any burnable-specific actions here if needed
        super._afterBurn(from, amount); // Call downstream hooks
    }

    /// @dev Provides the actual burn implementation by calling ERC20's internal _burn.
    ///      This assumes the contract inheriting this extension also inherits ERC20.
    function _burnable_executeBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(_SMARTBurnableLogic) // Implements the abstract function from the logic base
    {
        // Note: _burn is the internal function from the base ERC20 contract,
        // which MUST be inherited by the final contract using this extension.
        _burn(from, amount);
    }
}
