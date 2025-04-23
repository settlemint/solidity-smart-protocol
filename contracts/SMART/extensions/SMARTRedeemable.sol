// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { SMARTExtension } from "./SMARTExtension.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { _SMARTRedeemableLogic } from "./base/_SMARTRedeemableLogic.sol";
import { _Context } from "./base/interfaces/_Context.sol";
import { SMARTHooks } from "./common/SMARTHooks.sol";
/// @title SMARTRedeemable
/// @notice Standard (non-upgradeable) extension for SMART tokens allowing holders to redeem (burn) their tokens.
/// @dev Provides hooks for adding custom logic before and after redemption.
///      Inherits from Context, SMARTExtension, and _SMARTRedeemableLogic.

abstract contract SMARTRedeemable is SMARTExtension, _SMARTRedeemableLogic {
    // --- Hooks ---

    /// @dev Implements the abstract burn execution using ERC20._burn.
    function _redeemable_executeBurn(address from, uint256 amount) internal virtual override(_SMARTRedeemableLogic) {
        _burn(from, amount);
    }

    /// @notice Hook called before token redemption.
    /// @dev Can be overridden by inheriting contracts to add custom pre-redemption logic.
    /// @param owner The address redeeming the tokens.
    /// @param amount The amount of tokens being redeemed.
    function _beforeRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        // Placeholder for custom logic
        super._beforeRedeem(owner, amount);
    }

    /// @notice Hook called after token redemption.
    /// @dev Can be overridden by inheriting contracts to add custom post-redemption logic.
    /// @param owner The address that redeemed the tokens.
    /// @param amount The amount of tokens that were redeemed.
    function _afterRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        // Placeholder for custom logic
        super._afterRedeem(owner, amount);
    }

    function _msgSender() internal view virtual override(_Context, Context) returns (address) {
        return Context._msgSender();
    }

    function _msgData() internal view virtual override(_Context, Context) returns (bytes calldata) {
        return Context._msgData();
    }
}
