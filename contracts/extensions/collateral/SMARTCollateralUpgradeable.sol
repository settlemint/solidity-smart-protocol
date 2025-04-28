// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";
import { ISMART } from "./../../interface/ISMART.sol";

// Internal implementation imports
import { _SMARTCollateralLogic } from "./internal/_SMARTCollateralLogic.sol";

/// @title Upgradeable SMART Collateral Extension
/// @notice Adds collateral verification logic to an upgradeable SMART token before minting.
/// @dev Inherits the core collateral logic from `_SMARTCollateralLogic` and integrates it
///      into the upgradeable SMART token lifecycle using `Initializable`.
///      It expects the final contract to also inherit:
///      - `ERC20Upgradeable` (to provide `totalSupply`).
///      - The core `SMARTUpgradeable` implementation (to provide `onchainID`, `identityRegistry`).
///      - `SMARTHooks` (to provide the `_beforeMint` hook).
///      IMPORTANT: Ensure storage layout compatibility when upgrading.
abstract contract SMARTCollateralUpgradeable is Initializable, SMARTExtensionUpgradeable, _SMARTCollateralLogic {
    /// @notice Initializer for the upgradeable collateral extension.
    /// @dev Sets the collateral proof topic ID. Should be called only once, typically within the main contract's
    /// initializer.
    ///      Uses the `onlyInitializing` modifier from `_SMARTCollateral_init` indirectly via `_SMARTCollateral_init`.
    /// @param collateralProofTopic_ The ERC-735 claim topic ID for collateral verification.
    function __SMARTCollateralUpgradeable_init(uint256 collateralProofTopic_) internal onlyInitializing {
        // Call the internal initializer from the logic contract
        _SMARTCollateral_init(collateralProofTopic_);
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

    // Gap for upgrade safety
    uint256[50] private __gap;
}
