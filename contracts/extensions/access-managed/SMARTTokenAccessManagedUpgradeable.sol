// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { _SMARTTokenAccessManagedLogic } from "./internal/_SMARTTokenAccessManagedLogic.sol";
import { SMARTExtensionUpgradeable } from "../common/SMARTExtensionUpgradeable.sol";

/// @title Abstract contract for SMART tokens managed by a central Access Control Manager
/// @notice Provides storage and basic management for linking a token contract to its
///         `SMARTTokenAccessControlManager` instance.
/// @dev Inheriting contracts should call the constructor with the manager address and
///      implement the required authorization hooks by delegating to the manager.

abstract contract SMARTTokenAccessManagedUpgradeable is
    Initializable,
    SMARTExtensionUpgradeable,
    _SMARTTokenAccessManagedLogic
{
    // -- Initializer --

    /// @notice Initializes the access managed extension.
    function __SMARTTokenAccessManaged_init(address accessManager_) internal onlyInitializing {
        __SMARTTokenAccessManaged_init_unchained(accessManager_);
    }
}
