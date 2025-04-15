// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";
import { SMARTHooks } from "./SMARTHooks.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

/// @title SMARTPausable
/// @notice Extension that adds pausable functionality to SMART tokens
abstract contract SMARTPausable is ERC20Pausable, SMARTHooks, ISMART {
    bool private _paused;

    /// @dev Emitted when the pause is triggered by `account`.
    event Paused(address account);

    /// @dev Emitted when the pause is lifted by `account`.
    event Unpaused(address account);

    /// @dev Initializes the contract in unpaused state.
    constructor() {
        _paused = false;
    }

    /// @dev Returns true if the contract is paused, and false otherwise.
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused.
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /// @dev Triggers stopped state.
    function pause() public virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @dev Returns to normal state.
    function unpause() public virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Override validation hooks to include pausing checks
    function _validateMint(address _to, uint256 _amount) internal virtual override {
        require(!paused(), "Token is paused");
        super._validateMint(_to, _amount);
    }

    function _validateTransfer(address _from, address _to, uint256 _amount) internal virtual override {
        require(!paused(), "Token is paused");
        super._validateTransfer(_from, _to, _amount);
    }
}
