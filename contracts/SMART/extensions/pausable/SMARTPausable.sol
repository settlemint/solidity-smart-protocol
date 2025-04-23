// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { _SMARTPausableLogic } from "./_SMARTPausableLogic.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

/// @title SMARTPausable
/// @notice Standard (non-upgradeable) extension that adds pausable functionality.
/// @dev Inherits from OZ ERC20Pausable, Ownable, SMARTExtension, and _SMARTPausableLogic.
abstract contract SMARTPausable is ERC20Pausable, SMARTExtension, Ownable, _SMARTPausableLogic {
    // --- State-Changing Functions ---

    /// @notice Pauses the contract (Owner only).
    function pause() public virtual onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract (Owner only).
    function unpause() public virtual onlyOwner {
        _unpause();
    }

    // --- View Functions ---

    /// @dev Returns true if the contract is paused, and false otherwise.
    function paused() public view virtual override(Pausable, _SMARTPausableLogic) returns (bool) {
        return super.paused();
    }

    // --- Hooks ---

    /// @inheritdoc SMARTHooks
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _pausable_beforeMintLogic(); // Call helper from base logic
        super._beforeMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeTransfer(
        address from,
        address to,
        uint256 amount,
        bool forced
    )
        internal
        virtual
        override(SMARTHooks)
    {
        _pausable_beforeTransferLogic(); // Call helper from base logic
        super._beforeTransfer(from, to, amount, forced);
    }

    /// @inheritdoc SMARTHooks
    function _beforeBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _pausable_beforeBurnLogic(); // Call helper from base logic
        super._beforeBurn(from, amount);
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
