// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// --- Imports for SMARTTokenBase ---
import { SMART } from "../extensions/core/SMART.sol";
import { SMARTComplianceModuleParamPair } from "../interface/structs/SMARTComplianceModuleParamPair.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SMARTAccessControlAuthorization } from "../extensions/core/SMARTAccessControlAuthorization.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SMARTExtensionAccessControlAuthorization } from
    "../extensions/common/SMARTExtensionAccessControlAuthorization.sol";

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
        SMARTComplianceModuleParamPair[] memory initialModulePairs_,
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

    function _msgSender()
        internal
        view
        virtual
        override(Context, SMARTExtensionAccessControlAuthorization)
        returns (address)
    {
        return super._msgSender();
    }

    function hasRole(
        bytes32 role,
        address account
    )
        public
        view
        virtual
        override(AccessControl, SMARTExtensionAccessControlAuthorization)
        returns (bool)
    {
        return super.hasRole(role, account);
    }

    /// @dev Overrides ERC165 to ensure that the SMART implementation is used.
    function supportsInterface(bytes4 interfaceId) public view virtual override(SMART, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
