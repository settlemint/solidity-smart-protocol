// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// --- Imports for SMARTTokenBase ---
import { SMART } from "../extensions/core/SMART.sol";
import { SMARTComplianceModuleParamPair } from "../interface/structs/SMARTComplianceModuleParamPair.sol";
import { SMARTRedeemable } from "../extensions/redeemable/SMARTRedeemable.sol";
import { SMARTHooks } from "../extensions/common/SMARTHooks.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SMARTAccessControlAuthorization } from "../extensions/core/SMARTAccessControlAuthorization.sol";
import { SMARTExtensionAccessControlAuthorization } from
    "../extensions/common/SMARTExtensionAccessControlAuthorization.sol";

/// @title SMARTRedeemableTokenWithAuthorization
/// @notice A basic SMART token implementation with core features only.

contract SMARTRedeemableTokenWithAuthorization is
    SMART,
    SMARTRedeemable,
    SMARTAccessControlAuthorization,
    AccessControl
{
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
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

    // --- State-Changing Functions (Overrides) ---
    function transfer(address to, uint256 amount) public virtual override(SMART, ERC20, IERC20) returns (bool) {
        return super.transfer(to, amount);
    }

    // --- View Functions (Overrides) ---
    function name() public view virtual override(SMART, ERC20, IERC20Metadata) returns (string memory) {
        return super.name();
    }

    function symbol() public view virtual override(SMART, ERC20, IERC20Metadata) returns (string memory) {
        return super.symbol();
    }

    function decimals() public view virtual override(SMART, ERC20, IERC20Metadata) returns (uint8) {
        return super.decimals();
    }

    // --- Hooks (Overrides for Chaining) ---
    // These ensure that logic from multiple inherited extensions (SMART, SMARTCustodian, etc.) is called correctly.

    /// @inheritdoc SMARTRedeemable
    function _beforeRedeem(address owner, uint256 amount) internal virtual override(SMARTRedeemable, SMARTHooks) {
        super._beforeRedeem(owner, amount);
    }

    /// @inheritdoc SMARTRedeemable
    function _afterRedeem(address owner, uint256 amount) internal virtual override(SMARTRedeemable, SMARTHooks) {
        super._afterRedeem(owner, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeMint(address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._beforeMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeTransfer(address from, address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._beforeTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        super._beforeBurn(from, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterMint(address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterBurn(address from, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterBurn(from, amount);
    }

    // --- Internal Functions (Overrides) ---

    /**
     * @dev Overrides _update to ensure Pausable and Collateral checks are applied.
     */
    function _update(address from, address to, uint256 value) internal virtual override(SMART, ERC20) {
        // Calls chain: ERC20Collateral -> SMARTPausable -> SMART -> ERC20
        super._update(from, to, value);
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
}
