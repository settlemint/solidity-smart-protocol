// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTBurnableLogic } from "./internal/_SMARTBurnableLogic.sol";

/// @title Upgradeable SMART Burnable Extension
/// @notice Adds token burning functionality to an upgradeable SMART token.
/// @dev Inherits from `Initializable` and `SMARTExtensionUpgradeable`.
///      Implements the `_burnable_executeBurn` hook by calling the `_burn` function
///      from the base ERC20Upgradeable contract, which must be inherited by the final contract.
abstract contract SMARTBurnableUpgradeable is Initializable, SMARTExtensionUpgradeable, _SMARTBurnableLogic {
    // -- Initializer --

    /// @notice Initializes the burnable extension.
    /// @dev Should be called only once, typically within the main contract's initializer.
    ///      Uses the `onlyInitializing` modifier to prevent re-initialization.
    function __SMARTBurnable_init() internal onlyInitializing {
        // Intentionally empty: No specific state initialization needed for the burnable extension itself.
    }

    // -- Internal Hook Implementation --

    /// @dev Implements the core burn logic by calling the underlying ERC20Upgradeable `_burn` function.
    /// @param from The address from which tokens are burned.
    /// @param amount The amount of tokens to burn.
    /// @inheritdoc _SMARTBurnableLogic
    function _burnable_executeBurn(address from, uint256 amount) internal virtual override {
        // Note: Assumes the final contract inherits from ERC20Upgradeable
        // which provides the internal `_burn` function.
        _burn(from, amount);
    }
}
