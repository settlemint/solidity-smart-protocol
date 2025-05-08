// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
import { SMARTHooks } from "./../../common/SMARTHooks.sol";

/// @title Internal Logic for SMART Redeemable Extension
/// @notice Base contract containing the core logic and event for token redemption (self-burn).
/// @dev This abstract contract provides the `redeem` function, which allows a token holder to burn their own tokens.
///      It relies on abstract functions for burn execution and context (_msgSender, _msgData)
///      and integrates with standard SMARTHooks (_beforeRedeem, _afterRedeem).
abstract contract _SMARTRedeemableLogic is _SMARTExtension {
    // -- Events --

    /// @notice Emitted when tokens are successfully redeemed (burned by the holder).
    /// @param redeemer The address redeeming the tokens.
    /// @param amount The amount of tokens redeemed.
    event Redeemed(address indexed redeemer, uint256 amount);

    // -- Abstract Functions (Dependencies) --

    // -- State-Changing Functions --

    /// @notice Allows the caller (token holder) to redeem (burn) their own tokens.
    /// @dev Calls the `_beforeRedeem` hook, executes the burn via the abstract `_redeemable_executeBurn`,
    ///      calls the `_afterRedeem` hook, and emits the `Redeemed` event.
    ///      Relies on the inheriting contract to provide `_msgSender`.
    /// @param amount The amount of tokens the caller wishes to redeem.
    /// @return True upon successful execution.
    function redeem(uint256 amount) public virtual returns (bool) {
        address owner = _smartSender();
        _beforeRedeem(owner, amount); // Standard SMARTHook
        _redeem(owner, amount); // Abstract burn execution
        _afterRedeem(owner, amount); // Standard SMARTHook

        emit Redeemed(owner, amount);
        return true;
    }

    /// @notice Allows the caller (token holder) to redeem (burn) their own tokens.
    /// @dev Calls the `_beforeRedeem` hook, executes the burn via the abstract `_redeemable_executeBurn`,
    ///      calls the `_afterRedeem` hook, and emits the `Redeemed` event.
    ///      Relies on the inheriting contract to provide `_msgSender`.
    /// @return True upon successful execution.
    function redeemAll() external virtual returns (bool) {
        address owner = _smartSender();
        uint256 balance = _getRedeemableBalance(owner);
        return redeem(balance);
    }

    // -- Abstract Functions (Dependencies) --

    /// @notice Abstract function to retrieve the token balance of an account.
    /// @dev Must be implemented by inheriting contracts to call the appropriate balance function (e.g.,
    /// ERC20/ERC20Upgradeable.balanceOf).
    /// @param account The address whose balance is queried.
    /// @return The token balance of the account.
    function _getRedeemableBalance(address account) internal view virtual returns (uint256);

    /// @notice Abstract function representing the actual token burning mechanism.
    /// @dev Must be implemented by inheriting contracts to interact with the base token contract's burn function (e.g.,
    /// ERC20Burnable._burn).
    /// @param from The address whose tokens are being burned (the redeemer).
    /// @param amount The amount of tokens to burn.
    function _redeem(address from, uint256 amount) internal virtual;
}
