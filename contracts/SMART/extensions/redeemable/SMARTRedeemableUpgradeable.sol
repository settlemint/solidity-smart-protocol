// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { _SMARTExtension } from "./../common/_SMARTExtension.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTRedeemableLogic } from "./internal/_SMARTRedeemableLogic.sol";

/// @title SMARTRedeemableUpgradeable
/// @notice Upgradeable extension that adds redeemable functionality to SMART tokens.
/// @dev Relies on the main contract inheriting ERC20Upgradeable to provide the internal _burn function.
abstract contract SMARTRedeemableUpgradeable is
    Initializable,
    ContextUpgradeable,
    SMARTExtensionUpgradeable,
    _SMARTRedeemableLogic
{
    /// @dev Initializer for the redeemable extension.
    ///      Typically called by the main contract's initializer.
    function __SMARTRedeemable_init() internal onlyInitializing {
        // No specific state to initialize for Redeemable itself,
    }

    // @dev Abstract function representing the actual burn operation (e.g., ERC20Burnable._burn).
    function _redeemable_executeBurn(address from, uint256 amount) internal virtual override(_SMARTRedeemableLogic) {
        _burn(from, amount);
    }

    /// @notice Hook called before token redemption.
    /// @dev Can be overridden by inheriting contracts to add custom pre-redemption logic (e.g., check redemption
    /// conditions, trigger trade).
    /// @param owner The address redeeming the tokens.
    /// @param amount The amount of tokens being redeemed.
    function _beforeRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        // Placeholder for custom logic
        super._beforeRedeem(owner, amount);
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

    function _msgSender() internal view virtual override(_SMARTRedeemableLogic, ContextUpgradeable) returns (address) {
        return ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(_SMARTRedeemableLogic, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ContextUpgradeable._msgData();
    }
}
