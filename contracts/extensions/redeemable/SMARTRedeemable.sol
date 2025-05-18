// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";

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

    constructor() {
        __SMARTRedeemable_init_unchained();
    }

    // -- Internal Hook Implementations --

    /// @notice Implementation of the abstract balance getter using standard ERC20.balanceOf.
    /// @inheritdoc _SMARTRedeemableLogic
    function __redeemable_getBalance(address account) internal view virtual override returns (uint256) {
        return balanceOf(account); // Assumes ERC20.balanceOf is available
    }

    /// @notice Implementation of the abstract burn execution using the base ERC20 `_burn` function.
    /// @dev Assumes the inheriting contract includes an ERC20 implementation with an internal `_burn` function (e.g.,
    /// from ERC20Burnable).
    /// @inheritdoc _SMARTRedeemableLogic
    function __redeemable_redeem(address from, uint256 amount) internal virtual override {
        // Allowance check is typically NOT needed for self-burn/redeem.
        // The balance check is implicitly handled by the _burn function.
        // _spendAllowance(from, _msgSender(), amount);
        _burn(from, amount);
    }
}
