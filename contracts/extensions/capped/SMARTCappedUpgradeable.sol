// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.20;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";
import { ISMART } from "./../../interface/ISMART.sol";
import { SMARTContext } from "./../common/SMARTContext.sol";

// Internal implementation imports
import { _SMARTCappedLogic } from "./internal/_SMARTCappedLogic.sol";

/// @title Upgradeable SMART Capped Extension
/// @notice Adds a total supply cap to an upgradeable SMART token.
/// @dev Inherits the core capping logic from `_SMARTCappedLogic` and integrates it
///      into the upgradeable SMART token lifecycle via the `_beforeMint` hook.
///      It expects the final contract to also inherit:
///      - An `ERC20Upgradeable` implementation (to provide `totalSupply`).
///      - `SMARTHooksUpgradeable` (to provide the `_beforeMint` hook).
abstract contract SMARTCappedUpgradeable is Initializable, SMARTExtensionUpgradeable, _SMARTCappedLogic {
    /// @notice Initializes the upgradeable capped supply extension.
    /// @param cap_ The maximum total supply for the token. Must be greater than 0.
    function __SMARTCapped_init(uint256 cap_) internal onlyInitializing {
        __SMARTCapped_init_unchained(cap_);
    }

    // -- Internal Hook Implementations --

    function __capped_totalSupply() internal view virtual override returns (uint256) {
        return totalSupply(); // Assumes ERC20Upgradable.totalSupply is available
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
