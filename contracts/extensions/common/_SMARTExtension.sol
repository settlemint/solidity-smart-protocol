// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { ISMART } from "../../interface/ISMART.sol";
import { SMARTContext } from "../common/SMARTContext.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";
/// @title _SMARTExtension
/// @notice Base contract for SMART extension contracts.

abstract contract _SMARTExtension is ISMART, SMARTContext, SMARTHooks {
    bool internal __isForcedUpdate = false;

    // Mapping to check if an interface ID is registered for O(1) lookups.
    mapping(bytes4 => bool) internal _isInterfaceRegistered;

    /**
     * @dev Registers an interface ID internally for ERC165 support.
     *
     * This function is `internal` and intended to be called by derived contracts,
     * typically during their initialization or setup phase, to declare supported interfaces.
     *
     * @param interfaceId The bytes4 interface ID to register (e.g., `type(IMyInterface).interfaceId`).
     */
    function _registerInterface(bytes4 interfaceId) internal {
        _isInterfaceRegistered[interfaceId] = true;
    }
}
