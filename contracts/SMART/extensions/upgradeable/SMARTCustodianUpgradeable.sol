// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol"; // Needed for
    // _update, balanceOf context
import { SMARTExtensionUpgradeable } from "./SMARTExtensionUpgradeable.sol"; // Upgradeable extension base
import { _SMARTCustodianLogic } from "../base/_SMARTCustodianLogic.sol"; // Import base logic
import { ISMARTIdentityRegistry } from "../../interface/ISMARTIdentityRegistry.sol"; // Keep for _getIdentityRegistry
    // return type
import { IIdentity } from "../../../onchainid/interface/IIdentity.sol"; // Keep for _recoveryAddress usage
import { LengthMismatch } from "../common/CommonErrors.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";
/// @title SMARTCustodianUpgradeable
/// @notice Upgradeable extension that adds custodian features.
/// @dev Inherits from SMARTExtensionUpgradeable, OwnableUpgradeable, and _SMARTCustodianLogic.

abstract contract SMARTCustodianUpgradeable is
    Initializable,
    SMARTExtensionUpgradeable,
    OwnableUpgradeable,
    _SMARTCustodianLogic // Inherit base logic
{
    // State, Errors, Events are inherited from _SMARTCustodianLogic

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializer for the custodian extension.
    function __SMARTCustodian_init() internal onlyInitializing {
        // No specific state to initialize for Custodian itself
    }

    // --- State-Changing Functions (Public API) ---
    // Public functions delegate to internal logic in _SMARTCustodianLogic

    // These functions are new to this layer, so no 'override' needed from OwnableUpgradeable etc.
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
        _validateTransfer(from, to, amount); // Ensure custodian checks run first via hook chain
        _forcedTransfer(from, to, amount); // Call internal logic from base
        _afterTransfer(from, to, amount); // Call hook chain
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

    /// @dev Returns the token balance of an address using ERC20Upgradeable.balanceOf.
    function _getBalance(address account) internal view virtual override(_SMARTCustodianLogic) returns (uint256) {
        return balanceOf(account); // Use ERC20Upgradeable.balanceOf
    }

    /// @dev Returns the identity registry instance (must be provided by the inheriting SMART contract).
    function _getIdentityRegistry()
        internal
        view
        virtual
        override(_SMARTCustodianLogic)
        returns (ISMARTIdentityRegistry)
    {
        // Relies on the concrete SMARTUpgradeable contract implementing identityRegistry()
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
        // Relies on the concrete SMARTUpgradeable contract implementing requiredClaimTopics()
        return this.requiredClaimTopics();
    }

    /// @dev Executes the underlying token transfer using ERC20Upgradeable._update.
    function _executeTransferUpdate(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(_SMARTCustodianLogic)
    {
        // Call the internal _update function inherited from ERC20Upgradeable (via SMARTExtensionUpgradeable)
        _update(from, to, amount);
    }

    // --- Internal Hook Overrides ---
    // Override SMARTExtensionUpgradeable hooks to incorporate _SMARTCustodianLogic checks

    /// @inheritdoc SMARTHooks
    function _validateMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_validateMintLogic(to, amount); // Call renamed helper
        super._validateMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_validateTransferLogic(from, to, amount); // Call renamed helper
        super._validateTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_validateBurnLogic(from, amount); // Call renamed helper
        super._validateBurn(from, amount);
    }

    // --- Gap for upgradeability ---
    uint256[50] private __gap;
}
