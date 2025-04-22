// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { _Context } from "./interfaces/_Context.sol";
import { _SMARTExtension } from "./_SMARTExtension.sol";

/// @title _SMARTRedeemableLogic
/// @notice Base logic contract for SMARTRedeemable functionality.
/// @dev Contains the core redemption flow and abstract hooks.
abstract contract _SMARTRedeemableLogic is _SMARTExtension, _Context {
    // --- Events ---

    /// @notice Emitted when tokens are redeemed.
    /// @param redeemer The address redeeming the tokens.
    /// @param amount The amount of tokens redeemed.
    event Redeemed(address indexed redeemer, uint256 amount);

    // --- State-Changing Functions ---

    /// @notice Allows the caller to redeem (burn) their own tokens.
    /// @dev Calls abstract internal hooks and burn function.
    ///      Requires the concrete contract to provide _msgSender().
    /// @param amount The amount of tokens to redeem.
    function redeem(uint256 amount) external virtual returns (bool) {
        address owner = _msgSender(); // Requires _msgSender() from inheriting contract (Context / ContextUpgradeable)
        _validateRedeem(owner, amount);
        _validateBurn(owner, amount);
        _redeemable_executeBurn(owner, amount); // Abstracted burn execution
        _afterBurn(owner, amount);
        _afterRedeem(owner, amount);

        emit Redeemed(owner, amount);
        return true;
    }

    /// @dev Abstract function representing the actual burn operation (e.g., ERC20Burnable._burn).
    function _redeemable_executeBurn(address from, uint256 amount) internal virtual;
}
