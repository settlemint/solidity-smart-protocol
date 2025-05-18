// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { _SMARTExtension } from "./_SMARTExtension.sol";
import { SMARTContext } from "./SMARTContext.sol";
/// @title SMARTExtensionUpgradeable
/// @notice Abstract upgradeable contract that defines the internal hooks for SMART tokens.
/// @dev Base for upgradeable SMART extensions, inheriting essential upgradeable contracts.
///      These hooks should be called first in any override implementation.

abstract contract SMARTExtensionUpgradeable is Initializable, _SMARTExtension, ERC20Upgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _smartSender() internal view virtual override(SMARTContext) returns (address) {
        return _msgSender();
    }
}
