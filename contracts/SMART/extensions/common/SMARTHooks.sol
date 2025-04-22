// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

abstract contract SMARTHooks {
    /// Internal validation and hook functions
    /// @dev These functions should be called first in any override implementation
    function _validateMint(address _to, uint256 _amount) internal virtual {
        // Base validation logic can be added here if needed
    }

    /// @dev These functions should be called first in any override implementation
    function _afterMint(address _to, uint256 _amount) internal virtual {
        // Base after-mint logic can be added here if needed
    }

    /// @dev These functions should be called first in any override implementation
    function _validateTransfer(address _from, address _to, uint256 _amount) internal virtual {
        // Base validation logic can be added here if needed
    }

    /// @dev These functions should be called first in any override implementation
    function _afterTransfer(address _from, address _to, uint256 _amount) internal virtual {
        // Base after-transfer logic can be added here if needed
    }

    /// @dev These functions should be called first in any override implementation
    function _validateBurn(address _from, uint256 _amount) internal virtual {
        // Base validation logic can be added here if needed
    }

    /// @dev These functions should be called first in any override implementation
    function _afterBurn(address _from, uint256 _amount) internal virtual {
        // Base after-burn logic can be added here if needed
    }

    function _validateRedeem(address _from, uint256 _amount) internal virtual {
        // Base validation logic can be added here if needed
    }

    function _afterRedeem(address _from, uint256 _amount) internal virtual {
        // Base after-redeem logic can be added here if needed
    }
}
