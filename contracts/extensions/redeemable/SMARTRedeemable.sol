// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTRedeemableLogic } from "./internal/_SMARTRedeemableLogic.sol";

/// @title Standard SMART Redeemable Extension
/// @notice Standard (non-upgradeable) extension allowing token holders to redeem (burn) their own tokens.
/// @dev Inherits core redemption logic from `_SMARTRedeemableLogic`, `SMARTExtension`, and `Context`.
///      Implements the `_redeemable_executeBurn` function using the base ERC20 `_burn` function.
///      Provides virtual `_beforeRedeem` and `_afterRedeem` hooks for further customization.
///      Expects the final contract to inherit a standard `ERC20` (specifically one with a `_burn` function like
/// `ERC20Burnable`) and core `SMART` logic.
abstract contract SMARTRedeemable is Context, SMARTExtension, _SMARTRedeemableLogic {
    // Note: Assumes the final contract inherits ERC20 (with _burn) and SMART

    // -- Internal Hook Implementations --

    /// @notice Implementation of the abstract burn execution using the base ERC20 `_burn` function.
    /// @dev Assumes the inheriting contract includes an ERC20 implementation with an internal `_burn` function (e.g.,
    /// from ERC20Burnable).
    /// @inheritdoc _SMARTRedeemableLogic
    function _redeemable_executeBurn(address from, uint256 amount) internal virtual override {
        // Allowance check is typically NOT needed for self-burn/redeem.
        // The balance check is implicitly handled by the _burn function.
        // _spendAllowance(from, _msgSender(), amount);
        _burn(from, amount);
    }

    // -- Hooks (Overrides) --

    /// @notice Hook called before token redemption.
    /// @dev This is a virtual override of the hook defined in `SMARTHooks`.
    ///      Inheriting contracts can override this to add custom pre-redemption logic
    ///      (e.g., check eligibility, interact with external systems).
    /// @param owner The address redeeming the tokens.
    /// @param amount The amount of tokens being redeemed.
    function _beforeRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        // By default, calls the next hook in the inheritance chain (if any).
        super._beforeRedeem(owner, amount);
    }

    /// @notice Hook called after token redemption.
    /// @dev This is a virtual override of the hook defined in `SMARTHooks`.
    ///      Inheriting contracts can override this to add custom post-redemption logic
    ///      (e.g., finalize external actions, update records).
    /// @param owner The address that redeemed the tokens.
    /// @param amount The amount of tokens that were redeemed.
    function _afterRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        // By default, calls the next hook in the inheritance chain (if any).
        super._afterRedeem(owner, amount);
    }

    // -- Context Overrides --

    /// @dev Overrides `_msgSender` to resolve inheritance conflict.
    ///      Delegates to the `Context` implementation.
    function _msgSender() internal view virtual override(Context, _SMARTRedeemableLogic) returns (address) {
        return Context._msgSender();
    }

    /// @dev Overrides `_msgData` to resolve inheritance conflict.
    ///      Delegates to the `Context` implementation.
    function _msgData() internal view virtual override(Context, _SMARTRedeemableLogic) returns (bytes calldata) {
        return Context._msgData();
    }
}
