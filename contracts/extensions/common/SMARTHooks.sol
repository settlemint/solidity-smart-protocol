// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

abstract contract SMARTHooks {
    // --- Hooks ---

    //// @dev These functions should be last  in any override implementation
    function _beforeUpdate(address sender, address _from, address _to, uint256 _amount) internal virtual { }

    /// @dev These functions should be called last in any override implementation
    function _afterUpdate(address sender, address _from, address _to, uint256 _amount) internal virtual { }
}
