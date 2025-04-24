// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// Interface imports
import { ISMARTIdentityRegistry } from "../../interface/ISMARTIdentityRegistry.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTCustodianLogic } from "./internal/_SMARTCustodianLogic.sol";

// Error imports
import { LengthMismatch } from "./../common/CommonErrors.sol";

/// @title SMARTCustodianUpgradeable
/// @notice Upgradeable extension that adds custodian features.
/// @dev Inherits from SMARTExtensionUpgradeable and _SMARTCustodianLogic.
abstract contract SMARTCustodianUpgradeable is Initializable, SMARTExtensionUpgradeable, _SMARTCustodianLogic {
    // State, Errors, Events are inherited from _SMARTCustodianLogic

    // --- Initializer ---
    /// @dev Initializer for the custodian extension.
    function __SMARTCustodian_init() internal onlyInitializing { }

    // --- Hooks ---

    /// @dev Returns the token balance of an address using ERC20.balanceOf.
    function _getBalance(address account) internal view virtual override(_SMARTCustodianLogic) returns (uint256) {
        return balanceOf(account); // Use ERC20.balanceOf
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
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_beforeMintLogic(to, amount); // Call helper from base logic
        super._beforeMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_beforeTransferLogic(from, to, amount); // Call helper from base logic
        super._beforeTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_beforeBurnLogic(from, amount); // Call helper from base logic
        super._beforeBurn(from, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeRedeem(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_beforeRedeemLogic(from, amount); // Call helper from base logic
        super._beforeRedeem(from, amount);
    }
}
