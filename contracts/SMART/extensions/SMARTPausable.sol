// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import { ISMART } from "../interface/ISMART.sol";

/// @title SMARTPausable
/// @notice Extension that adds pausable functionality to SMART tokens
abstract contract SMARTPausable is ERC20Pausable, ISMART {
    /// @inheritdoc ERC20Pausable
    function pause() public virtual override {
        _pause();
    }

    /// @inheritdoc ERC20Pausable
    function unpause() public virtual override {
        _unpause();
    }

    /// @inheritdoc ERC20Pausable
    function paused() public view virtual override returns (bool) {
        return super.paused();
    }

    /// @inheritdoc ERC20Pausable
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
    }
}
