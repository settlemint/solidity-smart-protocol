// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// -- Events --

/// @title SMART Redeemable Extension Events
/// @notice This file defines events related to the redeemable functionality of SMART tokens.
/// Events are a way for smart contracts to log that something happened on the blockchain.
/// External applications or user interfaces can listen for these events to track activity.

/// @notice Emitted when tokens are successfully redeemed (burned by the token holder).
/// @dev This event is crucial for tracking the reduction of token supply due to redemptions.
/// It signifies that a token holder has voluntarily exchanged their tokens to have them permanently removed from
/// circulation.
/// Off-chain services can listen to this event to update balances, statistics, or trigger other processes.
/// The `indexed` keyword for `sender` allows for efficient searching and filtering of these events based on the
/// sender's address.
/// @param sender The address of the token holder who redeemed their tokens. This address initiated the redeem
/// transaction.
/// @param amount The quantity of tokens that were redeemed and thus burned. This is the amount by which the sender's
/// balance and the total supply decreased.
event Redeemed(address indexed sender, uint256 amount);
