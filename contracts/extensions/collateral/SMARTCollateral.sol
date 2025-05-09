// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";
import { ISMART } from "./../../interface/ISMART.sol";
import { SMARTContext } from "./../common/SMARTContext.sol";
// Internal implementation imports
import { _SMARTCollateralLogic } from "./internal/_SMARTCollateralLogic.sol";

/// @title Standard SMART Collateral Extension
/// @notice Adds collateral verification logic to a standard (non-upgradeable) SMART token before minting.
/// @dev Inherits the core collateral logic from `_SMARTCollateralLogic` and integrates it
///      into the standard SMART token lifecycle.
///      It expects the final contract to also inherit:
///      - A standard `ERC20` implementation (to provide `totalSupply`).
///      - The core `SMART` implementation (to provide `onchainID`, `identityRegistry`).
///      - `SMARTHooks` (to provide the `_beforeMint` hook).
abstract contract SMARTCollateral is SMARTExtension, _SMARTCollateralLogic {
    /// @notice Initializes the collateral extension with the required claim topic ID.
    /// @param collateralProofTopic_ The ERC-735 claim topic ID for collateral verification.
    constructor(uint256 collateralProofTopic_) {
        __SMARTCollateral_init_unchained(collateralProofTopic_);
    }

    // -- Hooks (Overrides) --

    /// @notice Hook executed before any mint operation.
    /// @dev Overrides the base `_beforeMint` hook from `SMARTHooks`.
    ///      Injects the collateral verification logic using `_collateral_beforeMintLogic`.
    ///      Calls `super._beforeMint` to ensure other potential hook implementations are executed.
    /// @inheritdoc SMARTHooks
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _collateral_beforeMintLogic(amount); // Check collateral claim against required total supply
        super._beforeMint(to, amount); // Call the next hook in the inheritance chain
    }
}
