// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// Base contract imports
import { _SMARTExtension } from "./_SMARTExtension.sol";

/// @title SMARTExtensionUpgradeable
/// @notice Abstract upgradeable contract that defines the internal hooks for SMART tokens.
/// @dev Base for upgradeable SMART extensions, inheriting essential upgradeable contracts.
///      These hooks should be called first in any override implementation.
abstract contract SMARTExtensionUpgradeable is Initializable, _SMARTExtension, ERC20Upgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
}
