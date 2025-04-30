// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// --- Imports for SMARTTokenBase ---
import { SMART } from "../extensions/core/SMART.sol";
import { ISMART } from "../interface/ISMART.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SMARTAccessControlAuthorization } from "../extensions/core/SMARTAccessControlAuthorization.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

/// @title SMARTCoreTokenWithAuthorization
/// @notice A basic SMART token implementation with core features only.
contract SMARTCoreTokenWithAuthorization is SMART, SMARTAccessControlAuthorization, AccessControl {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        ISMART.ComplianceModuleParamPair[] memory initialModulePairs_,
        address initialOwner_
    )
        SMART(
            name_,
            symbol_,
            decimals_,
            onchainID_,
            identityRegistry_,
            compliance_,
            requiredClaimTopics_,
            initialModulePairs_
        )
    {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner_);
    }

    function _msgSender() internal view virtual override(Context, SMARTAccessControlAuthorization) returns (address) {
        return super._msgSender();
    }

    function hasRole(
        bytes32 role,
        address account
    )
        public
        view
        virtual
        override(AccessControl, SMARTAccessControlAuthorization)
        returns (bool)
    {
        return super.hasRole(role, account);
    }
}
