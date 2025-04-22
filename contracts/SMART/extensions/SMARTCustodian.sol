// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";
import { SMARTExtension } from "./SMARTExtension.sol";
import { ISMARTIdentityRegistry } from "../interface/ISMARTIdentityRegistry.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IIdentity } from "../../onchainid/interface/IIdentity.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LengthMismatch } from "./common/CommonErrors.sol";
import { _SMARTCustodianLogic } from "./base/_SMARTCustodianLogic.sol";
import { SMARTHooks } from "./common/SMARTHooks.sol";

/// @title SMARTCustodian
/// @notice Standard (non-upgradeable) extension that adds custodian features.
/// @dev Inherits from SMARTExtension, Ownable, and _SMARTCustodianLogic.
abstract contract SMARTCustodian is SMARTExtension, Ownable, _SMARTCustodianLogic {
    // State, Errors, Events are inherited from _SMARTCustodianLogic

    // --- Constructor ---
    // No constructor needed unless initialization is required for this specific layer

    // --- State-Changing Functions (Public API) ---
    // Public functions delegate to internal logic in _SMARTCustodianLogic

    function setAddressFrozen(address userAddress, bool freeze) public virtual onlyOwner {
        _setAddressFrozen(userAddress, freeze);
    }

    function freezePartialTokens(address userAddress, uint256 amount) public virtual onlyOwner {
        _freezePartialTokens(userAddress, amount);
    }

    function unfreezePartialTokens(address userAddress, uint256 amount) public virtual onlyOwner {
        _unfreezePartialTokens(userAddress, amount);
    }

    function batchSetAddressFrozen(address[] calldata userAddresses, bool[] calldata freeze) public virtual onlyOwner {
        if (userAddresses.length != freeze.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _setAddressFrozen(userAddresses[i], freeze[i]);
        }
    }

    function batchFreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        public
        virtual
        onlyOwner
    {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _freezePartialTokens(userAddresses[i], amounts[i]);
        }
    }

    function batchUnfreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        public
        virtual
        onlyOwner
    {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _unfreezePartialTokens(userAddresses[i], amounts[i]);
        }
    }

    function forcedTransfer(address from, address to, uint256 amount) public virtual onlyOwner returns (bool) {
        _validateTransfer(from, to, amount);
        _forcedTransfer(from, to, amount);
        _afterTransfer(from, to, amount);
        return true;
    }

    function batchForcedTransfer(
        address[] calldata fromList,
        address[] calldata toList,
        uint256[] calldata amounts
    )
        public
        virtual
        onlyOwner
    {
        if (!((fromList.length == toList.length) && (toList.length == amounts.length))) {
            revert LengthMismatch();
        }
        for (uint256 i = 0; i < fromList.length; i++) {
            forcedTransfer(fromList[i], toList[i], amounts[i]);
        }
    }

    function recoveryAddress(
        address lostWallet,
        address newWallet,
        address investorOnchainID
    )
        public
        virtual
        onlyOwner
        returns (bool)
    {
        _recoveryAddress(lostWallet, newWallet, investorOnchainID);
        return true;
    }

    // --- Implementation of Abstract Functions from _SMARTCustodianLogic ---

    /// @dev Returns the token balance of an address using ERC20.balanceOf.
    function _getBalance(address account) internal view virtual override(_SMARTCustodianLogic) returns (uint256) {
        return balanceOf(account); // Use ERC20.balanceOf
    }

    /// @dev Returns the identity registry instance (must be provided by the inheriting SMART contract).
    function _getIdentityRegistry()
        internal
        view
        virtual
        override(_SMARTCustodianLogic)
        returns (ISMARTIdentityRegistry)
    {
        // This relies on the concrete SMART or SMARTUpgradeable contract implementing
        // the identityRegistry() view function from ISMART (via _SMARTLogic)
        return this.identityRegistry();
    }

    /// @dev Returns the required claim topics (must be provided by the inheriting SMART contract).
    function _getRequiredClaimTopics()
        internal
        view
        virtual
        override(_SMARTCustodianLogic)
        returns (uint256[] memory)
    {
        // This relies on the concrete SMART or SMARTUpgradeable contract implementing
        // the requiredClaimTopics() view function from ISMART (via _SMARTLogic)
        return this.requiredClaimTopics();
    }

    /// @dev Executes the underlying token transfer using ERC20._update.
    function _executeTransferUpdate(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(_SMARTCustodianLogic)
    {
        // Call the internal _update function inherited from ERC20 (via SMARTExtension)
        // This is crucial for forcedTransfer and recoveryAddress in the base logic
        _update(from, to, amount);
    }

    // --- Internal Hook Overrides ---
    // Override SMARTExtension hooks to incorporate _SMARTCustodianLogic checks

    /// @inheritdoc SMARTHooks
    function _validateMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        // Call Custodian check helper with new name
        _custodian_validateMintLogic(to, amount);
        super._validateMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        // Call Custodian check helper with new name
        _custodian_validateTransferLogic(from, to, amount);
        super._validateTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        // Call Custodian check helper with new name
        _custodian_validateBurnLogic(from, amount);
        super._validateBurn(from, amount);
    }

    // _afterMint, _afterTransfer, _afterBurn hooks are inherited from SMARTExtension
    // and eventually call _SMARTLogic hooks if SMART/SMARTUpgradeable is inherited.
    // No specific custodian logic needed *after* the action, only before (validation).
}
