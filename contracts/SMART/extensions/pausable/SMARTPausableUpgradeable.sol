// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTPausableLogic } from "./internal/_SMARTPausableLogic.sol";

/// @title SMARTPausableUpgradeable
/// @notice Upgradeable extension that adds pausable functionality.
/// @dev Inherits from OZ ERC20PausableUpgradeable, SMARTExtensionUpgradeable, and
/// _SMARTPausableLogic.

abstract contract SMARTPausableUpgradeable is Initializable, SMARTExtensionUpgradeable, _SMARTPausableLogic {
    // --- Hooks ---

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
        override(ERC20Upgradeable) // Specify both bases
        whenNotPaused
    {
        super._update(from, to, value); // Delegate to ERC20PausableUpgradeable._update
    }
}
