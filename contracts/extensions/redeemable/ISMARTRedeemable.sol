// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTRedeemable {
    // -- State-Changing Functions --

    /// @notice Allows the caller (token holder) to redeem (burn) their own tokens.
    /// @dev Calls the `_beforeRedeem` hook, executes the burn via the abstract `_redeemable_executeBurn`,
    ///      calls the `_afterRedeem` hook, and emits the `Redeemed` event.
    ///      Relies on the inheriting contract to provide `_msgSender`.
    /// @param amount The amount of tokens the caller wishes to redeem.
    /// @return True upon successful execution.
    function redeem(uint256 amount) external returns (bool);

    /// @notice Allows the caller (token holder) to redeem (burn) their own tokens.
    /// @dev Calls the `_beforeRedeem` hook, executes the burn via the abstract `_redeemable_executeBurn`,
    ///      calls the `_afterRedeem` hook, and emits the `Redeemed` event.
    ///      Relies on the inheriting contract to provide `_msgSender`.
    /// @return True upon successful execution.
    function redeemAll() external returns (bool);
}
