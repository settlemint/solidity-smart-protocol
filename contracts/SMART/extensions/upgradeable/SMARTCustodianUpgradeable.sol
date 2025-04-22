// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol"; // Needed for
    // _update, balanceOf context
import { SMARTExtensionUpgradeable } from "./SMARTExtensionUpgradeable.sol";
import { _SMARTCustodianLogic } from "../base/_SMARTCustodianLogic.sol";
import { ISMARTIdentityRegistry } from "../../interface/ISMARTIdentityRegistry.sol";
import { IIdentity } from "../../../onchainid/interface/IIdentity.sol";
import { LengthMismatch } from "../common/CommonErrors.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

/// @title SMARTCustodianUpgradeable
/// @notice Upgradeable extension that adds custodian features.
/// @dev Inherits from SMARTExtensionUpgradeable, OwnableUpgradeable, and _SMARTCustodianLogic.
abstract contract SMARTCustodianUpgradeable is
    Initializable,
    SMARTExtensionUpgradeable,
    OwnableUpgradeable,
    _SMARTCustodianLogic
{
    // State, Errors, Events are inherited from _SMARTCustodianLogic

    // --- Constructor ---
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @dev Initializer for the custodian extension.
    function __SMARTCustodian_init() internal onlyInitializing {
        // Initialization logic for Ownable, etc., is expected in the main contract's initializer.
    }

    // --- State-Changing Functions ---

    function setAddressFrozen(address userAddress, bool freeze) public virtual onlyOwner {
        _setAddressFrozen(userAddress, freeze); // Calls base logic
    }

    function freezePartialTokens(address userAddress, uint256 amount) public virtual onlyOwner {
        _freezePartialTokens(userAddress, amount); // Calls base logic
    }

    function unfreezePartialTokens(address userAddress, uint256 amount) public virtual onlyOwner {
        _unfreezePartialTokens(userAddress, amount); // Calls base logic
    }

    function batchSetAddressFrozen(address[] calldata userAddresses, bool[] calldata freeze) public virtual onlyOwner {
        if (userAddresses.length != freeze.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _setAddressFrozen(userAddresses[i], freeze[i]); // Calls base logic
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
            _freezePartialTokens(userAddresses[i], amounts[i]); // Calls base logic
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
            _unfreezePartialTokens(userAddresses[i], amounts[i]); // Calls base logic
        }
    }

    /// @dev Requires owner privileges.
    function forcedTransfer(address from, address to, uint256 amount) public virtual onlyOwner returns (bool) {
        _validateTransfer(from, to, amount); // Ensure custodian/other checks run first via hook chain
        _forcedTransfer(from, to, amount); // Call internal logic from base
        _afterTransfer(from, to, amount); // Call hook chain
        return true;
    }

    /// @dev Requires owner privileges.
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
            forcedTransfer(fromList[i], toList[i], amounts[i]); // Calls single forcedTransfer
        }
    }

    /// @dev Requires owner privileges.
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
        _recoveryAddress(lostWallet, newWallet, investorOnchainID); // Calls base logic
        return true;
    }

    // --- Hooks ---

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
        // Call the internal _update function inherited from ERC20Upgradeable
        _update(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_validateMintLogic(to, amount); // Call helper from base logic
        super._validateMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_validateTransferLogic(from, to, amount); // Call helper from base logic
        super._validateTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_validateBurnLogic(from, amount); // Call helper from base logic
        super._validateBurn(from, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateRedeem(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_validateRedeemLogic(from, amount); // Call helper from base logic
        super._validateRedeem(from, amount);
    }

    // --- Gap ---
    /// @dev Gap for upgradeability.
    uint256[50] private __gap;
}
