// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
/// @title _SMARTRedeemableLogic
/// @notice Base logic contract for SMARTRedeemable functionality.
/// @dev Contains the core redemption flow and abstract hooks.

abstract contract _SMARTRedeemableLogic is _SMARTExtension {
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
        _beforeRedeem(owner, amount);
        _beforeBurn(owner, amount);
        _redeemable_executeBurn(owner, amount); // Abstracted burn execution
        _afterBurn(owner, amount);
        _afterRedeem(owner, amount);

        emit Redeemed(owner, amount);
        return true;
    }

    /// @dev Abstract function representing the actual burn operation (e.g., ERC20Burnable._burn).
    function _redeemable_executeBurn(address from, uint256 amount) internal virtual;

    function _msgSender() internal view virtual returns (address);

    function _msgData() internal view virtual returns (bytes calldata);
}
