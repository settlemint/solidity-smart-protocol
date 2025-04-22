// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SMARTExtensionUpgradeable } from "./SMARTExtensionUpgradeable.sol";
import { _SMARTPausableLogic } from "../base/_SMARTPausableLogic.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

/// @title SMARTPausableUpgradeable
/// @notice Upgradeable extension that adds pausable functionality.
/// @dev Inherits from OZ ERC20PausableUpgradeable, OwnableUpgradeable, SMARTExtensionUpgradeable, and
/// _SMARTPausableLogic.
abstract contract SMARTPausableUpgradeable is
    Initializable,
    ERC20PausableUpgradeable,
    SMARTExtensionUpgradeable,
    OwnableUpgradeable,
    _SMARTPausableLogic
{
    // --- Constructor ---
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @dev Initializer for the pausable extension.
    function __SMARTPausable_init() internal onlyInitializing {
        __Pausable_init(); // Initialize Pausable state
    }

    // --- State-Changing Functions ---

    /// @notice Pauses the contract (Owner only).
    function pause() public virtual onlyOwner {
        _pause(); // Call PausableUpgradeable internal function
    }

    /// @notice Unpauses the contract (Owner only).
    function unpause() public virtual onlyOwner {
        _unpause(); // Call PausableUpgradeable internal function
    }

    // --- View Functions ---

    /// @dev Returns true if the contract is paused, and false otherwise.
    function paused() public view virtual override(PausableUpgradeable, _SMARTPausableLogic) returns (bool) {
        return super.paused(); // Delegate to PausableUpgradeable.paused()
    }

    // --- Hooks ---

    /// @inheritdoc SMARTHooks
    function _validateMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _pausable_validateMintLogic(); // Call helper from base logic
        super._validateMint(to, amount); // Call downstream validation
    }

    /// @inheritdoc SMARTHooks
    function _validateTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        _pausable_validateTransferLogic(); // Call helper from base logic
        super._validateTransfer(from, to, amount); // Call downstream validation
    }

    /// @inheritdoc SMARTHooks
    function _validateBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _pausable_validateBurnLogic(); // Call helper from base logic
        super._validateBurn(from, amount);
    }

    /**
     * @dev Overrides _update to resolve conflict between ERC20PausableUpgradeable and base ERC20Upgradeable,
     *      ensuring the whenNotPaused modifier from PausableUpgradeable is applied.
     */
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC20PausableUpgradeable, ERC20Upgradeable) // Specify both bases
    {
        super._update(from, to, value); // Delegate to ERC20PausableUpgradeable._update
    }

    // --- Gap ---
    /// @dev Gap for upgradeability.
    uint256[50] private __gap;
}
