// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { _SMARTExtension } from "./../common/_SMARTExtension.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTRedeemableLogic } from "./internal/_SMARTRedeemableLogic.sol";

/// @title Upgradeable SMART Redeemable Extension
/// @notice Upgradeable extension allowing token holders to redeem (burn) their own tokens.
/// @dev Inherits core redemption logic from `_SMARTRedeemableLogic`, `SMARTExtensionUpgradeable`, `ContextUpgradeable`,
/// and `Initializable`.
///      Implements the `_redeemable_executeBurn` function using the base ERC20Upgradeable `_burn` function.
///      Provides virtual `_beforeRedeem` and `_afterRedeem` hooks for further customization.
///      Expects the final contract to inherit `ERC20Upgradeable` (with a `_burn` function) and core `SMARTUpgradeable`
/// logic.
abstract contract SMARTRedeemableUpgradeable is
    Initializable,
    ContextUpgradeable,
    SMARTExtensionUpgradeable,
    _SMARTRedeemableLogic
{
    // Note: Assumes the final contract inherits ERC20Upgradeable (with _burn) and SMARTUpgradeable

    // -- Initializer --
    /// @notice Initializes the redeemable extension specific state (currently none).
    /// @dev Should be called within the main contract's `initialize` function.
    ///      Uses the `onlyInitializing` modifier.
    function __SMARTRedeemable_init() internal onlyInitializing {
        __SMARTRedeemable_init_unchained();
    }

    // -- Internal Hook Implementations --

    /// @notice Implementation of the abstract balance getter using standard ERC20.balanceOf.
    /// @inheritdoc _SMARTRedeemableLogic
    function _getRedeemableBalance(address account) internal view virtual override returns (uint256) {
        return balanceOf(account); // Assumes ERC20.balanceOf is available
    }

    /// @notice Implementation of the abstract burn execution using the base ERC20Upgradeable `_burn` function.
    /// @dev Assumes the inheriting contract includes an ERC20Upgradeable implementation with an internal `_burn`
    /// function.
    /// @inheritdoc _SMARTRedeemableLogic
    function _redeem(address from, uint256 amount) internal virtual override {
        // Allowance check is typically NOT needed for self-burn/redeem.
        _burn(from, amount);
    }

    // -- Hooks (Overrides) --

    /// @notice Hook called before token redemption.
    /// @dev This is a virtual override of the hook defined in `SMARTHooks`.
    ///      Inheriting contracts can override this to add custom pre-redemption logic.
    /// @param owner The address redeeming the tokens.
    /// @param amount The amount of tokens being redeemed.
    function _beforeRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        super._beforeRedeem(owner, amount);
    }

    /// @notice Hook called after token redemption.
    /// @dev This is a virtual override of the hook defined in `SMARTHooks`.
    ///      Inheriting contracts can override this to add custom post-redemption logic.
    /// @param owner The address that redeemed the tokens.
    /// @param amount The amount of tokens that were redeemed.
    function _afterRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        super._afterRedeem(owner, amount);
    }
}
