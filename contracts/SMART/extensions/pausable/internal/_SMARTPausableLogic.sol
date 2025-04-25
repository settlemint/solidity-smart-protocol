// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { _SMARTPausableAuthorizationHooks } from "./_SMARTPausableAuthorizationHooks.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";
import { TokenPaused, ExpectedPause } from "./../SMARTPausableErrors.sol";

/// @title _SMARTPausableLogic
/// @notice Base logic contract for SMARTPausable functionality.
/// @dev Contains validation hooks checking the paused state.
abstract contract _SMARTPausableLogic is _SMARTExtension, _SMARTPausableAuthorizationHooks {
    // State variable to track pause status
    bool private _paused;

    // Events for pause state changes
    event Paused(address account);
    event Unpaused(address account);

    // Implement abstract functions
    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() external {
        _authorizePause();
        require(!_paused, "Contract is already paused");
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external {
        _authorizePause();
        require(_paused, "Contract is not paused");
        _paused = false;
        emit Unpaused(msg.sender);
    }

    // Add custom modifiers that use the pause state
    modifier whenNotPaused() {
        if (paused()) {
            revert TokenPaused();
        }
        _;
    }

    modifier whenPaused() {
        if (!paused()) {
            revert ExpectedPause();
        }
        _;
    }
}
