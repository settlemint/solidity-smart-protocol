// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { SMARTExtension } from "./SMARTExtension.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { _SMARTPausableLogic } from "./base/_SMARTPausableLogic.sol";
import { SMARTHooks } from "./common/SMARTHooks.sol";

/// @title SMARTPausable
/// @notice Standard (non-upgradeable) extension that adds pausable functionality.
/// @dev Inherits from OZ ERC20Pausable, Ownable, SMARTExtension, and _SMARTPausableLogic.
abstract contract SMARTPausable is ERC20Pausable, SMARTExtension, Ownable, _SMARTPausableLogic {
    // Error inherited from _SMARTPausableLogic

    // --- State-Changing Functions ---
    /// @dev Triggers stopped state.
    /// Requires the contract not to be paused.
    /// Requires caller to have appropriate permission (e.g., owner).
    /// Emits a {Paused} event (from Pausable).
    function pause() public virtual onlyOwner {
        _pause();
    }

    /// @dev Returns to normal state.
    /// Requires the contract to be paused.
    /// Requires caller to have appropriate permission (e.g., owner).
    /// Emits an {Unpaused} event (from Pausable).
    function unpause() public virtual onlyOwner {
        _unpause();
    }

    // --- View Functions ---
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual override(Pausable, _SMARTPausableLogic) returns (bool) {
        return super.paused();
    }

    // --- Internal Functions ---
    /// @inheritdoc SMARTHooks
    function _validateMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        // Call Pausable check helper with new name
        _pausable_validateMintLogic();
        super._validateMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        // Call Pausable check helper with new name
        _pausable_validateTransferLogic();
        super._validateTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _pausable_validateBurnLogic();
        super._validateBurn(from, amount);
    }

    /**
     * @dev Overrides _update to resolve conflict between ERC20Pausable and SMARTExtension,
     * ensuring the whenNotPaused modifier is applied.
     */
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC20Pausable, ERC20)
        whenNotPaused
    {
        super._update(from, to, value);
    }
}
