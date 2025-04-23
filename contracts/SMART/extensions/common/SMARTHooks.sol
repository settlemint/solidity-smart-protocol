// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

abstract contract SMARTHooks {
    // --- Hooks ---

    /// @dev These functions should be called first in any override implementation
    function _validateMint(address _to, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _afterMint(address _to, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _validateTransfer(address _from, address _to, uint256 _amount, bool _forced) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _afterTransfer(address _from, address _to, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _validateBurn(address _from, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _afterBurn(address _from, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _validateRedeem(address _from, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _afterRedeem(address _from, uint256 _amount) internal virtual { }
}
