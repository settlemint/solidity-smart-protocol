// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Events for the SMART Burnable Extension
/// @notice This file defines the events related to token burning operations within the SMART framework.
///         Events in Solidity are a way for contracts to log important actions that have occurred on the
///         blockchain. External applications (like user interfaces or analytics tools) can listen for
///         these events to track contract activity and react accordingly without constantly querying the contract's
/// state.

/// @notice Emitted when a token burn operation has been successfully completed.
/// @dev This event signifies that a specified `amount` of tokens has been destroyed from the `from` address,
///      triggered by the `sender`.
///      The `indexed` keyword for `sender` and `from` parameters is a special feature in Solidity events.
///      It allows these parameters to be efficiently searched and filtered by off-chain applications.
///      Think of them as creating a searchable index for these specific fields in the event logs.
/// @param sender The address of the account that initiated or authorized the burn operation.
///               This could be an administrator, an operator, or under certain rules, the token holder themselves.
/// @param from The address from which the tokens were actually burned. This is the account whose token balance was
/// reduced.
/// @param amount The quantity of tokens that were burned (destroyed).
event BurnCompleted(address indexed sender, address indexed from, uint256 amount);
