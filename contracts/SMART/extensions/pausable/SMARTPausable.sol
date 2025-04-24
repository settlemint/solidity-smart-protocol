// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTPausableLogic } from "./internal/_SMARTPausableLogic.sol";

/// @title SMARTPausable
/// @notice Standard (non-upgradeable) extension that adds pausable functionality.
/// @dev Inherits from OZ ERC20Pausable, SMARTExtension, and _SMARTPausableLogic.

abstract contract SMARTPausable is SMARTExtension, _SMARTPausableLogic {
    // --- Hooks ---

    /**
     * @dev Overrides _update to resolve conflict between ERC20Pausable and SMARTExtension,
     * ensuring the whenNotPaused modifier is applied.
     */
    function _update(address from, address to, uint256 value) internal virtual override(ERC20) whenNotPaused {
        super._update(from, to, value);
    }
}
