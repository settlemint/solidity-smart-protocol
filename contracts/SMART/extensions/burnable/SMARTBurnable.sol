// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTBurnableLogic } from "./internal/_SMARTBurnableLogic.sol";

/// @title SMARTBurnable
/// @notice Standard (non-upgradeable) extension that adds burnable functionality to SMART tokens.
/// @dev Inherits from SMARTExtension, and _SMARTBurnableLogic.
///      Relies on the main contract inheriting ERC20 to provide the internal _burn function.

abstract contract SMARTBurnable is SMARTExtension, _SMARTBurnableLogic {
    // No constructor needed unless initialization is required

    // --- Hooks ---

    /// @dev Provides the actual burn implementation by calling ERC20's internal _burn.
    ///      This assumes the contract inheriting this extension also inherits ERC20.
    function _burnable_executeBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(_SMARTBurnableLogic) // Implements the abstract function from the logic base
    {
        // Note: _burn is the internal function from the base ERC20 contract,
        // which MUST be inherited by the final contract using this extension.
        _burn(from, amount);
    }
}
