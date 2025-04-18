// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// Removed ISMART import - not directly used
// import { ISMART } from "../interface/ISMART.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { SMARTExtension } from "./SMARTExtension.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LengthMismatch } from "./common/CommonErrors.sol";
import { _SMARTBurnableLogic } from "./base/_SMARTBurnableLogic.sol"; // Import base logic

/// @title SMARTBurnable
/// @notice Standard (non-upgradeable) extension that adds burnable functionality to SMART tokens.
/// @dev Inherits from OZ ERC20Burnable, Ownable, SMARTExtension, and _SMARTBurnableLogic.
abstract contract SMARTBurnable is
    ERC20Burnable, // Provides the standard _burn function
    SMARTExtension,
    Ownable,
    _SMARTBurnableLogic // Inherit base logic
{
    // No constructor needed unless initialization is required

    /// @notice Burns a specific amount of tokens from a user's address
    /// @param userAddress The address to burn tokens from
    /// @param amount The amount of tokens to burn
    /// @dev Requires caller to be the owner.
    function burn(address userAddress, uint256 amount) public virtual onlyOwner {
        // Call the internal implementation from the base logic contract
        _burnInternal(userAddress, amount);
    }

    /// @notice Burns tokens from multiple addresses in a single transaction
    /// @param userAddresses The addresses to burn tokens from
    /// @param amounts The amounts of tokens to burn from each address
    /// @dev Requires caller to be the owner.
    function batchBurn(address[] calldata userAddresses, uint256[] calldata amounts) public virtual onlyOwner {
        // Call the internal implementation from the base logic contract
        _batchBurnInternal(userAddresses, amounts);
    }

    // --- Hook Implementations ---
    // Implement the abstract functions required by _SMARTBurnableLogic
    // by calling the functions provided by SMARTExtension and ERC20Burnable.

    /// @dev Internal validation hook for burning tokens.
    function _validateBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(SMARTExtension, _SMARTBurnableLogic)
    {
        // No specific logic helper to call from _SMARTBurnableLogic for validation
        // Add any burnable-specific validation here if needed
        super._validateBurn(from, amount); // Call downstream validation (e.g., SMARTCustodian, SMART)
    }

    /// @dev Internal hook called after burning tokens.
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTExtension, _SMARTBurnableLogic) {
        // No specific logic helper to call from _SMARTBurnableLogic for this hook
        // Add any burnable-specific actions here if needed
        super._afterBurn(from, amount); // Call downstream hooks (e.g., SMART)
    }

    /// @dev Provides the actual burn implementation by calling ERC20Burnable's internal _burn.
    function _executeBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(_SMARTBurnableLogic) // Implements the abstract function from the logic base
    {
        _burn(from, amount); // Call the _burn function inherited directly from ERC20Burnable
    }
}
