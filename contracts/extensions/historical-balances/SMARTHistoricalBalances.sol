// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTHistoricalBalancesLogic } from "./internal/_SMARTHistoricalBalancesLogic.sol";

/// @title Standard SMART Historical Balances Extension
/// @notice Standard (non-upgradeable) extension for tracking historical token balances and total supply.
/// @dev This contract inherits the core historical balances logic from `_SMARTHistoricalBalancesLogic`
///      and integrates it with the standard `SMART` token framework by overriding the necessary SMARTHooks
///      (`_afterMint`, `_afterBurn`, `_afterTransfer`).
///      It is intended to be inherited by a standard (non-upgradeable) `SMART` token contract.
///      The final contract is expected to also inherit a standard `ERC20` implementation and the core `SMART` logic.
abstract contract SMARTHistoricalBalances is Context, SMARTExtension, _SMARTHistoricalBalancesLogic {
    /// @dev Hook that is called after any token minting.
    ///      Updates historical total supply and the recipient's balance.
    /// @param to The address that received the minted tokens.
    /// @param amount The amount of tokens minted.
    function _afterMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        super._afterMint(to, amount); // Call next hook in the chain (e.g., SMARTHooks implementation in SMART.sol)
        _historical_balances_afterMintLogic(to, amount); // Call historical balances specific logic
    }

    /// @dev Hook that is called after any token burning.
    ///      Updates historical total supply and the burner's balance.
    /// @param from The address whose tokens were burned.
    /// @param amount The amount of tokens burned.
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        super._afterBurn(from, amount); // Call next hook in the chain
        _historical_balances_afterBurnLogic(from, amount); // Call historical balances specific logic
    }

    /// @dev Hook that is called after any token transfer.
    ///      Updates historical balances for both the sender and the recipient.
    /// @param from The address that sent the tokens.
    /// @param to The address that received the tokens.
    /// @param amount The amount of tokens transferred.
    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        super._afterTransfer(from, to, amount); // Call next hook in the chain
        _historical_balances_afterTransferLogic(from, to, amount); // Call historical balances specific logic
    }
}
