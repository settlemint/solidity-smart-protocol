// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
import { SMARTHooks } from "./../../common/SMARTHooks.sol";
import { Redeemed } from "./../SMARTRedeemableEvents.sol";
import { ISMARTRedeemable } from "./../ISMARTRedeemable.sol";
/// @title Internal Logic for SMART Redeemable Extension
/// @notice Base contract containing the core logic and event for token redemption (self-burn).
/// @dev This abstract contract provides the `redeem` function, which allows a token holder to burn their own tokens.
///      It relies on abstract functions for burn execution and context (_msgSender, _msgData)
///      and integrates with standard SMARTHooks (_beforeRedeem, _afterRedeem).

abstract contract _SMARTRedeemableLogic is _SMARTExtension, ISMARTRedeemable {
    // -- Initializer --
    function __SMARTRedeemable_init_unchained() internal {
        _registerInterface(type(ISMARTRedeemable).interfaceId);
    }

    // -- Abstract Functions (Dependencies) --

    /// @notice Abstract function to retrieve the token balance of an account.
    /// @dev Must be implemented by inheriting contracts to call the appropriate balance function (e.g.,
    /// ERC20/ERC20Upgradeable.balanceOf).
    /// @param account The address whose balance is queried.
    /// @return The token balance of the account.
    function __redeemable_getBalance(address account) internal view virtual returns (uint256);

    /// @notice Abstract function representing the actual token burning mechanism.
    /// @dev Must be implemented by inheriting contracts to interact with the base token contract's burn function (e.g.,
    /// ERC20Burnable._burn).
    /// @param from The address whose tokens are being burned (the redeemer).
    /// @param amount The amount of tokens to burn.
    function __redeemable_redeem(address from, uint256 amount) internal virtual;

    // -- Internal Implementation for SMARTRedeemable interface functions --

    /// @inheritdoc ISMARTRedeemable
    function redeem(uint256 amount) external virtual returns (bool) {
        __smart_redeemLogic(amount);
        return true;
    }

    /// @inheritdoc ISMARTRedeemable
    function redeemAll() external virtual returns (bool) {
        address owner = _smartSender();
        uint256 balance = __redeemable_getBalance(owner);
        __smart_redeemLogic(balance);
        return true;
    }

    // -- Internal Functions --
    function __smart_redeemLogic(uint256 amount) internal virtual {
        address owner = _smartSender();
        __redeemable_redeem(owner, amount); // Abstract burn execution

        emit Redeemed(owner, amount);
    }
}
