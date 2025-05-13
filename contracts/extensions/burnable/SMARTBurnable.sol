// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTBurnableLogic } from "./internal/_SMARTBurnableLogic.sol";

/// @title Standard SMART Burnable Extension
/// @notice Adds token burning functionality to a standard (non-upgradeable) SMART token.
/// @dev Implements the `_burnable_executeBurn` hook by calling the `_burn` function
///      from the base ERC20 contract, which must be inherited by the final contract.

abstract contract SMARTBurnable is SMARTExtension, _SMARTBurnableLogic {
    constructor() payable {
        __SMARTBurnable_init_unchained();
    }
    // -- Internal Hook Implementations (Dependencies) --

    /// @dev Implements the core burn logic by calling the underlying ERC20 `_burn` function.
    /// @param from The address from which tokens are burned.
    /// @param amount The amount of tokens to burn.
    /// @inheritdoc _SMARTBurnableLogic
    function __burnable_executeBurn(address from, uint256 amount) internal virtual override {
        // Note: Assumes the final contract inherits from a standard ERC20 implementation
        // that provides the internal `_burn` function.
        _burn(from, amount);
    }
}
