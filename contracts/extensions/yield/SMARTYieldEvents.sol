// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Events for the SMART Yield Extension
/// @notice This file defines events related to the yield extension functionality.
/// Events are used by smart contracts to broadcast that something significant has occurred on the blockchain.
/// These events can be monitored by off-chain applications, user interfaces, or other smart contracts to react to
/// changes or track activity.

/// @notice Emitted when a new yield schedule is successfully set or updated for a token.
/// @dev This event is critical for transparency and tracking changes to how a token generates and distributes yield.
/// When this event is emitted, it signifies that the `schedule` address is now the authoritative contract dictating
/// the terms of yield for this token.
/// The `indexed` keyword for `sender` and `schedule` allows for efficient searching and filtering of these events based
/// on these addresses.
/// For example, one could easily find all tokens for which a specific yield schedule was set, or all schedules set by a
/// particular admin.
/// @param sender The address of the account (e.g., an admin or owner) that initiated the transaction to set the yield
/// schedule.
/// @param schedule The address of the newly set yield schedule contract. This contract implements `ISMARTYieldSchedule`
/// and contains the yield logic.
event YieldScheduleSet(address indexed sender, address indexed schedule);
