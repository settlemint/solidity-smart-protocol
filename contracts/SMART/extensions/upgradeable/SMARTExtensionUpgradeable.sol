// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ISMART } from "../../interface/ISMART.sol"; // Assuming ISMART doesn't need an upgradeable version itself
import { _SMARTExtension } from "../base/_SMARTExtension.sol";

/// @title SMARTExtensionUpgradeable
/// @notice Abstract upgradeable contract that defines the internal hooks for SMART tokens
/// @dev These hooks should be called first in any override implementation
abstract contract SMARTExtensionUpgradeable is Initializable, _SMARTExtension, ERC20Upgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // --- Gap for upgradeability ---
    // Leave a gap for future storage variables to avoid storage collisions.
    // The size depends on the number of expected future variables. 50 is a common choice.
    uint256[50] private __gap;
}
