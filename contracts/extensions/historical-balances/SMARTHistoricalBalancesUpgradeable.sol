// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTHistoricalBalancesLogic } from "./internal/_SMARTHistoricalBalancesLogic.sol";

/// @title Upgradeable SMART Historical Balances Extension
/// @notice Upgradeable extension for tracking historical token balances and total supply.
/// @dev This contract inherits the core historical balances logic from `_SMARTHistoricalBalancesLogic`
///      and integrates it with the upgradeable `SMART` token framework by overriding the necessary SMARTHooks
///      (`_afterMint`, `_afterBurn`, `_afterTransfer`).
///      It is intended to be inherited by an upgradeable `SMART` token contract.
///      The final contract is expected to also inherit `ERC20Upgradeable` and core `SMARTUpgradeable` logic.
///      Includes an initializer `__SMARTHistoricalBalances_init`.
abstract contract SMARTHistoricalBalancesUpgradeable is
    Initializable,
    SMARTExtensionUpgradeable,
    _SMARTHistoricalBalancesLogic
{
    /// @dev Initializes the SMART Historical Balances extension.
    ///      This function should be called by the final contract's initializer.
    function __SMARTHistoricalBalances_init() internal onlyInitializing {
        __SMARTHistoricalBalances_init_unchained();
    }

    /// @dev Hook that is called after any token minting.
    ///      Updates historical total supply and the recipient's balance.
    /// @param to The address that received the minted tokens.
    /// @param amount The amount of tokens minted.
    function _afterMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        super._afterMint(to, amount); // Call next hook in the chain
        __historical_balances_afterMintLogic(to, amount); // Call historical balances specific logic
    }

    /// @dev Hook that is called after any token burning.
    ///      Updates historical total supply and the burner's balance.
    /// @param from The address whose tokens were burned.
    /// @param amount The amount of tokens burned.
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        super._afterBurn(from, amount); // Call next hook in the chain
        __historical_balances_afterBurnLogic(from, amount); // Call historical balances specific logic
    }

    /// @dev Hook that is called after any token transfer.
    ///      Updates historical balances for both the sender and the recipient.
    /// @param from The address that sent the tokens.
    /// @param to The address that received the tokens.
    /// @param amount The amount of tokens transferred.
    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        super._afterTransfer(from, to, amount); // Call next hook in the chain
        __historical_balances_afterTransferLogic(from, to, amount); // Call historical balances specific logic
    }
}
