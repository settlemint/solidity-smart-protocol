// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// ContextUpgradeable is imported by ERC20Upgradeable, so direct import might be redundant but harmless.
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
// Context is imported for the SMARTContext override signature, not directly used for its functions here.
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { _SMARTExtension } from "./_SMARTExtension.sol";
import { SMARTContext } from "./SMARTContext.sol";
/// @title Upgradeable SMART Token Extension Base
/// @notice This abstract contract serves as a foundational base for all upgradeable SMART token extensions.
///         It combines common SMART functionalities with an upgradeable ERC20 token framework.
///         'Upgradeable' means the contract's logic can be changed after deployment via a proxy pattern,
///         without changing the contract's address.
/// @dev It inherits from `Initializable` (for managing initialization in upgradeable contracts),
///      `_SMARTExtension` (for common SMART logic and hooks), and OpenZeppelin's `ERC20Upgradeable`.
///      It provides an implementation for `_smartSender()` from `SMARTContext` by delegating to `_msgSender()`,
///      which in `ERC20Upgradeable` (via `ContextUpgradeable` and potentially `ERC2771ContextUpgradeable`
///      if further inherited) can support meta-transactions.
///      The constructor calls `_disableInitializers()` to prevent re-initialization of this base contract part
///      when an inheriting contract is initialized through a proxy. This is a standard safety measure for
///      OpenZeppelin Upgradeable contracts.
///      The comment "These hooks should be called first in any override implementation" is a general guideline
///      for developers extending SMART hooks: always call `super.hookFunction(...)` in overrides.

abstract contract SMARTExtensionUpgradeable is Initializable, _SMARTExtension, ERC20Upgradeable {
    /// @notice Constructor for the upgradeable extension base.
    /// @dev This constructor is typically called when the implementation contract (logic contract)
    ///      is deployed, but not when it's initialized via a proxy.
    ///      It calls `_disableInitializers()` as a safeguard. In OpenZeppelin's upgradeable contracts pattern,
    ///      initialization logic is placed in `initializer` functions (like `__ERC20_init`), not constructors.
    ///      `_disableInitializers()` sets a flag indicating that all `initializer` modifiers in this contract
    ///      and its `Initializable` parents should prevent their respective `initializer` functions from running again.
    ///      The `@custom:oz-upgrades-unsafe-allow constructor` tag is used to inform OpenZeppelin's upgrade tools
    ///      that this constructor is intentionally present and understood in an upgradeable contract context.
    constructor() {
        _disableInitializers();
    }

    /// @notice Returns the effective sender of the current transaction, supporting meta-transactions if configured.
    /// @dev This function overrides `_smartSender()` from `SMARTContext`.
    ///      It calls `_msgSender()`, which in `ERC20Upgradeable` (potentially via `ERC2771ContextUpgradeable`
    ///      if the final contract uses it for meta-transactions) will return the original user's address
    ///      even if the call came through a trusted forwarder.
    ///      If not using ERC2771, it defaults to `msg.sender` (via `ContextUpgradeable`).
    /// @return address The address of the transaction initiator.
    function _smartSender() internal view virtual override(SMARTContext) returns (address) {
        return _msgSender(); // In ERC20Upgradeable, _msgSender() can support meta-tx via ERC2771ContextUpgradeable.
    }

    /// @inheritdoc _SMARTExtension
    /// @notice Implements the abstract `__smartExtension_executeTransfer` from `_SMARTExtension`.
    /// @dev Provides the concrete token transfer action by calling OpenZeppelin `ERC20._transfer`.
    ///      Called by `_SMARTExtension._smart_transfer`.
    /// @param from The sender address.
    /// @param to The recipient address.
    /// @param amount The amount of tokens to transfer.
    function __smartExtension_executeTransfer(address from, address to, uint256 amount) internal virtual override {
        _transfer(from, to, amount); // Calls OZ ERC20 _transfer function
    }

    /// @inheritdoc _SMARTExtension
    /// @notice Implements the abstract `__smart_balanceOf` from `_SMARTLogic`.
    /// @dev Provides the concrete token balance retrieval action by calling OpenZeppelin `ERC20.balanceOf`.
    /// @param account The address to query the balance of.
    /// @return The balance of the specified account.
    function __smartExtension_balanceOf(address account) internal virtual override returns (uint256) {
        return balanceOf(account);
    }
}
