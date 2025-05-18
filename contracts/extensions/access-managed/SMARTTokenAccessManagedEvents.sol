// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Custom Events for SMART Token Access Management
/// @notice This file defines custom events that can be emitted by contracts related to
///         SMART token access management. Events in Solidity are a way for contracts
///         to log significant occurrences on the blockchain. Off-chain applications
///         can listen for these events to track contract activity, update user interfaces,
///         or trigger other processes.

/// @notice Emitted when the address of the access manager contract is successfully changed or set.
/// @dev This event is crucial for transparency and monitoring. It allows external observers
///      to know when the authority managing roles and permissions for a token has been updated.
///      The `indexed` keyword for `sender` and `manager` allows these addresses to be efficiently
///      searched for in event logs.
/// @param sender The address of the account that initiated the change of the access manager.
///               This is typically an administrator or an account with special privileges.
/// @param manager The new address of the `SMARTTokenAccessManager` contract that will now
///                oversee access control for the token.
event AccessManagerSet(address indexed sender, address indexed manager);
