// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// --- Imports for SMARTTokenBase ---
import { SMART } from "../extensions/core/SMART.sol";
import { ISMART } from "../interface/ISMART.sol";

/// @title SMARTCoreToken
/// @notice A basic SMART token implementation with core features only.
contract SMARTCoreToken is SMART {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        ISMART.ComplianceModuleParamPair[] memory initialModulePairs_
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
    { }

    // --- Authorization Hook Implementations ---
    // Implementing the abstract functions from _SMART*AuthorizationHooks

    function _authorizeUpdateTokenSettings() internal view virtual override {
        // Do nothing
    }

    function _authorizeUpdateComplianceSettings() internal view virtual override {
        // Do nothing
    }

    function _authorizeUpdateVerificationSettings() internal view virtual override {
        // Do nothing
    }

    function _authorizeMintToken() internal view virtual override {
        // Do nothing
    }

    function _authorizeRecoverERC20() internal view virtual override {
        // Do nothing
    }
}
