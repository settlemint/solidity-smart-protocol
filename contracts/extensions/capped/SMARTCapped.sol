// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.20;

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";
import { ISMART } from "./../../interface/ISMART.sol";
import { SMARTContext } from "./../common/SMARTContext.sol";

// Internal implementation imports
import { _SMARTCappedLogic } from "./internal/_SMARTCappedLogic.sol";

/// @title Standard SMART Capped Extension
/// @notice Adds a total supply cap to a standard (non-upgradeable) SMART token.
/// @dev Inherits the core capping logic from `_SMARTCappedLogic` and integrates it
///      into the standard SMART token lifecycle via the `_beforeMint` hook.
///      It expects the final contract to also inherit:
///      - A standard `ERC20` implementation (to provide `totalSupply`).
///      - `SMARTHooks` (to provide the `_beforeMint` hook).
abstract contract SMARTCapped is SMARTExtension, _SMARTCappedLogic {
    /// @notice Initializes the capped supply extension with the maximum total supply.
    /// @param cap_ The maximum total supply for the token. Must be greater than 0.
    constructor(uint256 cap_) {
        __SMARTCapped_init_unchained(cap_);
    }
    // -- Internal Hook Implementations --

    function __capped_totalSupply() internal view virtual override returns (uint256) {
        return totalSupply(); // Assumes ERC20.totalSupply is available
    }

    // -- Hooks (Overrides) --

    /// @notice Hook executed before any mint operation.
    /// @dev Overrides the base `_beforeMint` hook from `SMARTHooks`.
    ///      Injects the supply capping logic using `__capped_beforeMintLogic`.
    ///      Calls `super._beforeMint` to ensure other potential hook implementations are executed.
    /// @inheritdoc SMARTHooks
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        __capped_beforeMintLogic(amount); // Check cap before minting
        super._beforeMint(to, amount); // Call the next hook in the inheritance chain
    }
}
