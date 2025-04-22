// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SMARTExtensionUpgradeable } from "./SMARTExtensionUpgradeable.sol"; // Upgradeable extension base
import { _SMARTExtension } from "../base/_SMARTExtension.sol";
import { _SMARTRedeemableLogic } from "../base/_SMARTRedeemableLogic.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { _Context } from "../base/interfaces/_Context.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

/// @title SMARTRedeemableUpgradeable
/// @notice Upgradeable extension that adds redeemable functionality to SMART tokens.
/// @dev Relies on the main contract inheriting ERC20Upgradeable to provide the internal _burn function.
abstract contract SMARTRedeemableUpgradeable is
    Initializable,
    ContextUpgradeable,
    SMARTExtensionUpgradeable,
    _SMARTRedeemableLogic
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializer for the redeemable extension.
    ///      Typically called by the main contract's initializer.
    function __SMARTRedeemable_init() internal onlyInitializing {
        // No specific state to initialize for Redeemable itself,
        // but ensures Ownable is initialized by the main contract.
    }

    // @dev Abstract function representing the actual burn operation (e.g., ERC20Burnable._burn).
    function _executeBurn(address from, uint256 amount) internal virtual override(_SMARTRedeemableLogic) {
        _burn(from, amount);
    }

    /// @notice Hook called before token redemption.
    /// @dev Can be overridden by inheriting contracts to add custom pre-redemption logic (e.g., check redemption
    /// conditions, trigger trade).
    /// @param owner The address redeeming the tokens.
    /// @param amount The amount of tokens being redeemed.
    function _validateRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        // Placeholder for custom logic
        super._validateRedeem(owner, amount);
    }

    /// @notice Hook called after token redemption.
    /// @dev Can be overridden by inheriting contracts to add custom post-redemption logic (e.g., finalize trade, update
    /// off-chain records).
    /// @param owner The address that redeemed the tokens.
    /// @param amount The amount of tokens that were redeemed.
    function _afterRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        // Placeholder for custom logic
        super._afterRedeem(owner, amount);
    }

    function _msgSender() internal view virtual override(_Context, ContextUpgradeable) returns (address) {
        return ContextUpgradeable._msgSender();
    }

    function _msgData() internal view virtual override(_Context, ContextUpgradeable) returns (bytes calldata) {
        return ContextUpgradeable._msgData();
    }

    // --- Gap for upgradeability ---
    uint256[50] private __gap;
}
