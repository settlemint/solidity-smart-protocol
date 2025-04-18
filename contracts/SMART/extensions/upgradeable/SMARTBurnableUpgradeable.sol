// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20BurnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SMARTExtensionUpgradeable } from "./SMARTExtensionUpgradeable.sol"; // Upgradeable extension base
import { _SMARTBurnableLogic } from "../base/_SMARTBurnableLogic.sol"; // Import base logic
import { LengthMismatch } from "../common/CommonErrors.sol";

/// @title SMARTBurnableUpgradeable
/// @notice Upgradeable extension that adds burnable functionality to SMART tokens.
/// @dev Inherits from OZ ERC20BurnableUpgradeable, OwnableUpgradeable, SMARTExtensionUpgradeable, and
/// _SMARTBurnableLogic.
abstract contract SMARTBurnableUpgradeable is
    Initializable,
    ERC20BurnableUpgradeable, // Provides the upgradeable _burn function
    SMARTExtensionUpgradeable,
    OwnableUpgradeable,
    _SMARTBurnableLogic // Inherit base logic
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializer for the burnable extension.
    ///      Typically called by the main contract's initializer.
    function __SMARTBurnable_init() internal onlyInitializing {
        // No specific state to initialize for Burnable itself,
        // but ensures Ownable is initialized by the main contract.
    }

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
    // by calling the functions provided by SMARTExtensionUpgradeable and ERC20BurnableUpgradeable.

    /// @dev Internal validation hook for burning tokens.
    function _validateBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(SMARTExtensionUpgradeable, _SMARTBurnableLogic)
    {
        // No specific logic helper to call from _SMARTBurnableLogic for validation
        // Add any burnable-specific validation here if needed
        super._validateBurn(from, amount); // Call downstream validation
    }

    /// @dev Internal hook called after burning tokens.
    function _afterBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(SMARTExtensionUpgradeable, _SMARTBurnableLogic)
    {
        // No specific logic helper to call from _SMARTBurnableLogic for this hook
        // Add any burnable-specific actions here if needed
        super._afterBurn(from, amount); // Call downstream hooks
    }

    /// @dev Provides the actual burn implementation by calling ERC20BurnableUpgradeable's internal _burn.
    function _executeBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(_SMARTBurnableLogic) // Implements the abstract function from the logic base
    {
        _burn(from, amount); // Call the _burn function inherited directly from ERC20BurnableUpgradeable
    }

    // --- Gap for upgradeability ---
    uint256[50] private __gap;
}
