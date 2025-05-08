// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

abstract contract SMARTHooks {
    // --- Hooks ---

    /// @dev These functions should be called first in any override implementation
    function _beforeMint(address _to, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _afterMint(address _to, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _beforeTransfer(address _from, address _to, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _afterTransfer(address _from, address _to, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _beforeBurn(address _from, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _afterBurn(address _from, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _beforeRedeem(address _from, uint256 _amount) internal virtual { }

    /// @dev These functions should be called first in any override implementation
    function _afterRedeem(address _from, uint256 _amount) internal virtual { }
}
