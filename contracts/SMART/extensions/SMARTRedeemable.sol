// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { SMARTExtension } from "./SMARTExtension.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { _SMARTRedeemableLogic } from "./base/_SMARTRedeemableLogic.sol";
import { _SMARTExtension } from "./base/_SMARTExtension.sol";
import { _Context } from "./base/interfaces/_Context.sol";
import { SMARTHooks } from "./common/SMARTHooks.sol";
/// @title SMARTRedeemable
/// @notice Extension for SMART tokens allowing holders to redeem (burn) their tokens.
/// @dev Provides hooks for adding custom logic before and after redemption.
/// Inherits from SMARTExtension to integrate with SMART token lifecycle hooks.

abstract contract SMARTRedeemable is Context, SMARTExtension, _SMARTRedeemableLogic {
    /// @dev Abstract function representing the actual burn operation (e.g., ERC20Burnable._burn).
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

    function _msgSender() internal view virtual override(_Context, Context) returns (address) {
        return Context._msgSender();
    }

    function _msgData() internal view virtual override(_Context, Context) returns (bytes calldata) {
        return Context._msgData();
    }
}
