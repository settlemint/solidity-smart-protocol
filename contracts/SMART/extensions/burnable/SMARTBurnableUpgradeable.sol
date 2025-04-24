// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTBurnableLogic } from "./internal/_SMARTBurnableLogic.sol";

// Error imports
import { LengthMismatch } from "./../common/CommonErrors.sol";

/// @title SMARTBurnableUpgradeable
/// @notice Upgradeable extension that adds burnable functionality to SMART tokens.
/// @dev Inherits from Initializable, SMARTExtensionUpgradeable, and _SMARTBurnableLogic.
/// @dev Relies on the main contract inheriting ERC20Upgradeable to provide the internal _burn function.
abstract contract SMARTBurnableUpgradeable is Initializable, SMARTExtensionUpgradeable, _SMARTBurnableLogic {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializer for the burnable extension.
    ///      Typically called by the main contract's initializer.
    function __SMARTBurnable_init() internal onlyInitializing {
        // No specific state to initialize for Burnable itself,
    }

    /// @notice Burns a specific amount of tokens from a user's address
    /// @param userAddress The address to burn tokens from
    /// @param amount The amount of tokens to burn
    /// @dev Requires caller to be the owner. Matches IERC3643 signature.
    function burn(address userAddress, uint256 amount) public virtual {
        // Call the internal implementation from the base logic contract
        _burnInternal(userAddress, amount);
    }

    /// @notice Burns tokens from multiple addresses in a single transaction
    /// @param userAddresses The addresses to burn tokens from
    /// @param amounts The amounts of tokens to burn from each address
    /// @dev Requires caller to be the owner.
    function batchBurn(address[] calldata userAddresses, uint256[] calldata amounts) public virtual {
        // Call the internal implementation from the base logic contract
        _batchBurnInternal(userAddresses, amounts);
    }

    // --- Hook Implementations ---
    // Implement the abstract functions required by _SMARTBurnableLogic
    // by calling the functions provided by SMARTExtensionUpgradeable and relying on ERC20Upgradeable's _burn.

    /// @dev Internal validation hook for burning tokens.
    function _beforeBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        // No specific logic helper to call from _SMARTBurnableLogic for validation
        // Add any burnable-specific validation here if needed
        super._beforeBurn(from, amount); // Call downstream validation
    }

    /// @dev Internal hook called after burning tokens.
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        // No specific logic helper to call from _SMARTBurnableLogic for this hook
        // Add any burnable-specific actions here if needed
        super._afterBurn(from, amount); // Call downstream hooks
    }

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

    // --- Gap for upgradeability ---
    uint256[50] private __gap;
}
