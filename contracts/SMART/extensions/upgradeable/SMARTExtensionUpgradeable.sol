// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ISMART } from "../../interface/ISMART.sol"; // Assuming ISMART doesn't need an upgradeable version itself

/// @title SMARTExtensionUpgradeable
/// @notice Abstract upgradeable contract that defines the internal hooks for SMART tokens
/// @dev These hooks should be called first in any override implementation
abstract contract SMARTExtensionUpgradeable is Initializable, ERC20Upgradeable, ISMART {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // --- Internal Hooks ---

    /// @dev Validation hook called before minting. Should be overridden by extensions.
    ///      Ensure `super._validateMint` is called in overrides.
    function _validateMint(address _to, uint256 _amount) internal virtual {
        // Base validation logic (if any) can be added here in the future
    }

    /// @dev Hook called after minting. Should be overridden by extensions.
    ///      Ensure `super._afterMint` is called in overrides.
    function _afterMint(address _to, uint256 _amount) internal virtual {
        // Base after-mint logic (if any) can be added here in the future
    }

    /// @dev Validation hook called before transferring. Should be overridden by extensions.
    ///      Ensure `super._validateTransfer` is called in overrides.
    function _validateTransfer(address _from, address _to, uint256 _amount) internal virtual {
        // Base validation logic (if any) can be added here in the future
    }

    /// @dev Hook called after transferring. Should be overridden by extensions.
    ///      Ensure `super._afterTransfer` is called in overrides.
    function _afterTransfer(address _from, address _to, uint256 _amount) internal virtual {
        // Base after-transfer logic (if any) can be added here in the future
    }

    /// @dev Validation hook called before burning. Should be overridden by extensions.
    ///      Ensure `super._validateBurn` is called in overrides.
    function _validateBurn(address _from, uint256 _amount) internal virtual {
        // Base validation logic (if any) can be added here in the future
    }

    /// @dev Hook called after burning. Should be overridden by extensions.
    ///      Ensure `super._afterBurn` is called in overrides.
    function _afterBurn(address _from, uint256 _amount) internal virtual {
        // Base after-burn logic (if any) can be added here in the future
    }

    // --- Gap for upgradeability ---
    // Leave a gap for future storage variables to avoid storage collisions.
    // The size depends on the number of expected future variables. 50 is a common choice.
    uint256[50] private __gap;
}
