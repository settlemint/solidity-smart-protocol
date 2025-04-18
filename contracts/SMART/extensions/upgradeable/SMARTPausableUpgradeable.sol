// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol"; // For paused()
    // override
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SMARTExtensionUpgradeable } from "./SMARTExtensionUpgradeable.sol"; // Upgradeable extension base
import { _SMARTPausableLogic } from "../base/_SMARTPausableLogic.sol"; // Import base logic
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol"; // For _update
    // override

/// @title SMARTPausableUpgradeable
/// @notice Upgradeable extension that adds pausable functionality.
/// @dev Inherits from OZ ERC20PausableUpgradeable, OwnableUpgradeable, SMARTExtensionUpgradeable, and
/// _SMARTPausableLogic.
abstract contract SMARTPausableUpgradeable is
    Initializable,
    ERC20PausableUpgradeable, // Provides upgradeable _pause, _unpause, paused, whenNotPaused
    SMARTExtensionUpgradeable,
    OwnableUpgradeable,
    _SMARTPausableLogic // Inherit base logic
{
    // Error inherited from _SMARTPausableLogic

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializer for the pausable extension.
    function __SMARTPausable_init() internal onlyInitializing {
        __Pausable_init(); // Initialize Pausable state
    }

    // --- State-Changing Functions ---
    // Keep public pause/unpause, applying onlyOwner
    // No 'override' needed as these are new functions in this layer
    function pause() public virtual onlyOwner {
        _pause(); // Call PausableUpgradeable internal function
    }

    function unpause() public virtual onlyOwner {
        _unpause(); // Call PausableUpgradeable internal function
    }

    // --- View Functions ---
    /// @dev Returns true if the contract is paused, and false otherwise.
    ///      Override needed to specify all base contracts.
    function paused() public view virtual override(PausableUpgradeable, _SMARTPausableLogic) returns (bool) {
        return super.paused(); // Delegate to PausableUpgradeable.paused()
    }

    // --- Internal Functions ---
    // Override validation hooks to incorporate _SMARTPausableLogic checks via super

    /// @inheritdoc SMARTExtensionUpgradeable
    function _validateMint(address to, uint256 amount) internal virtual override(SMARTExtensionUpgradeable) {
        _pausable_validateMintLogic(); // Call renamed helper
        super._validateMint(to, amount); // Call downstream validation
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _validateTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTExtensionUpgradeable)
    {
        _pausable_validateTransferLogic(); // Call renamed helper
        super._validateTransfer(from, to, amount); // Call downstream validation
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _validateBurn(address from, uint256 amount) internal virtual override(SMARTExtensionUpgradeable) {
        _pausable_validateBurnLogic();
        super._validateBurn(from, amount);
    }

    /**
     * @dev Overrides _update to resolve conflict between ERC20PausableUpgradeable and base ERC20Upgradeable.
     * Ensures the whenNotPaused modifier from PausableUpgradeable is applied.
     */
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC20PausableUpgradeable, ERC20Upgradeable) // Specify both bases
            // whenNotPaused modifier is applied by ERC20PausableUpgradeable's implementation
    {
        super._update(from, to, value); // Delegate to ERC20PausableUpgradeable._update
    }

    // --- Gap for upgradeability ---
    uint256[50] private __gap;
}
