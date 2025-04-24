// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTBurnableLogic } from "./internal/_SMARTBurnableLogic.sol";

/// @title SMARTBurnableUpgradeable
/// @notice Upgradeable extension that adds burnable functionality to SMART tokens.
/// @dev Inherits from Initializable, SMARTExtensionUpgradeable, and _SMARTBurnableLogic.
/// @dev Relies on the main contract inheriting ERC20Upgradeable to provide the internal _burn function.
abstract contract SMARTBurnableUpgradeable is Initializable, SMARTExtensionUpgradeable, _SMARTBurnableLogic {
    /// @dev Initializer for the burnable extension.
    ///      Typically called by the main contract's initializer.
    function __SMARTBurnable_init() internal onlyInitializing {
        // No specific state to initialize for Burnable itself,
    }

    // --- Hook Implementations ---
    // Implement the abstract functions required by _SMARTBurnableLogic
    // by calling the functions provided by SMARTExtensionUpgradeable and relying on ERC20Upgradeable's _burn.

    /// @dev Provides the actual burn implementation by calling ERC20Upgradeable's internal _burn.
    ///      This assumes the contract inheriting this extension also inherits ERC20Upgradeable.
    function _burnable_executeBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(_SMARTBurnableLogic) // Implements the abstract function from the logic base
    {
        // Note: _burn is the internal function from the base ERC20Upgradeable contract,
        // which MUST be inherited by the final contract using this extension.
        _burn(from, amount);
    }
}
