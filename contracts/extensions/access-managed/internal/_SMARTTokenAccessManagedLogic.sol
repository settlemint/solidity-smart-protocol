// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { ZeroAddressNotAllowed } from "../../common/CommonErrors.sol";
import { ISMARTTokenAccessManaged } from "./../ISMARTTokenAccessManaged.sol";
import { ISMARTTokenAccessManager } from "./../manager/ISMARTTokenAccessManager.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";
import { AccessManagerSet } from "../SMARTTokenAccessManagedEvents.sol";
import { AccessControlUnauthorizedAccount } from "../SMARTTokenAccessManagedErrors.sol";

/// @title Internal Logic for SMART Burnable Extension
/// @notice Contains the core internal logic and event for burning tokens.
/// @dev This contract provides the `burn` and `batchBurn` functions and defines
///      abstract hooks for authorization and execution.

abstract contract _SMARTTokenAccessManagedLogic is _SMARTExtension, ISMARTTokenAccessManaged {
    /// @notice The address of the central access control manager contract.
    address public _accessManager;

    // -- Internal Setup Function --
    function __SMARTTokenAccessManaged_init_unchained(address accessManager_) internal {
        if (accessManager_ == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        _accessManager = accessManager_;

        _registerInterface(type(ISMARTTokenAccessManaged).interfaceId);
        emit AccessManagerSet(_smartSender(), accessManager_);
    }

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyAccessManagerRole(bytes32 role) {
        _checkRole(role, _smartSender());
        _;
    }

    function hasRole(bytes32 role, address account) external view virtual returns (bool) {
        return _hasRole(role, account);
    }

    function _hasRole(bytes32 role, address account) internal view returns (bool) {
        return ISMARTTokenAccessManager(_accessManager).hasRole(role, account);
    }

    function _checkRole(bytes32 role, address account) internal view {
        if (!_hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }
}
