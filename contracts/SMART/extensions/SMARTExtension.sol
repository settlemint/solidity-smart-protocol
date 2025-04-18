// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ISMART } from "../interface/ISMART.sol";
/// @title SMARTExtension
/// @notice Abstract contract that defines the internal hooks for SMART tokens
/// @dev These hooks should be called first in any override implementation

abstract contract SMARTExtension is ERC20, ISMART {
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
}
