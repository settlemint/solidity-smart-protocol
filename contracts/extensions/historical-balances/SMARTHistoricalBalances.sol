// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";
import { SMARTContext } from "./../common/SMARTContext.sol";

// Internal implementation imports
import { _SMARTHistoricalBalancesLogic } from "./internal/_SMARTHistoricalBalancesLogic.sol";

/// @title Standard SMART Historical Balances Extension
/// @notice Standard (non-upgradeable) extension for tracking historical token balances and total supply.
/// @dev This contract inherits the core historical balances logic from `_SMARTHistoricalBalancesLogic`
///      and integrates it with the standard `SMART` token framework by overriding the necessary SMARTHooks
///      (`_afterMint`, `_afterBurn`, `_afterTransfer`).
///      It is intended to be inherited by a standard (non-upgradeable) `SMART` token contract.
///      The final contract is expected to also inherit a standard `ERC20` implementation and the core `SMART` logic.
abstract contract SMARTHistoricalBalances is SMARTExtension, _SMARTHistoricalBalancesLogic {
    constructor() {
        __SMARTHistoricalBalances_init_unchained();
    }

    /// @dev Hook that is called after any token minting.
    ///      Updates historical total supply and the recipient's balance.
    /// @param to The address that received the minted tokens.
    /// @param amount The amount of tokens minted.
    function _afterUpdate(
        address sender,
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTHooks)
    {
        super._afterUpdate(sender, from, to, amount); // Call next hook in the chain (e.g., SMARTHooks implementation in
            // SMART.sol)
        __historical_balances_afterUpdateLogic(from, to, amount); // Call historical balances specific logic
    }
}
