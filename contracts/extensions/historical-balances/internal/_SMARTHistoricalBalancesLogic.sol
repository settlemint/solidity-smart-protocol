// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
import { SMARTHooks } from "./../../common/SMARTHooks.sol";
import { FutureLookup } from "./../SMARTHistoricalBalancesErrors.sol";
import { ISMARTHistoricalBalances } from "./../ISMARTHistoricalBalances.sol";
import { CheckpointUpdated } from "./../SMARTHistoricalBalancesEvents.sol";

import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Time } from "@openzeppelin/contracts/utils/types/Time.sol";

/// @title Internal Logic for SMART Historical Balances Extension
/// @notice Base contract providing the core logic for tracking historical token balances and total supply.
/// @dev This abstract contract implements checkpointing mechanisms to record balances and total supply
///      at different timepoints (block numbers by default). It provides functions to query these historical values.
///      It integrates with standard SMARTHooks (`_afterMint`, `_afterBurn`, `_afterTransfer`)
///      via internal logic functions (`_historical_balances_afterMintLogic`, etc.).
abstract contract _SMARTHistoricalBalancesLogic is _SMARTExtension, ISMARTHistoricalBalances {
    using Checkpoints for Checkpoints.Trace208;

    // -- State Variables --

    // Track historical balances for each account
    mapping(address account => Checkpoints.Trace208 checkpoints) private _balanceCheckpoints;

    // Track historical total supply
    Checkpoints.Trace208 private _totalSupplyCheckpoints;

    // -- Internal Setup Function --

    /// @notice Initializes the historical balances extension.
    /// @dev This function should only be called once during the contract's initialization phase.
    function __SMARTHistoricalBalances_init_unchained() internal {
        _registerInterface(type(ISMARTHistoricalBalances).interfaceId);
    }

    // -- Timekeeping --

    /// @dev Returns the current timepoint used for timestamping checkpoints.
    ///      By default, this is the current block number.
    /// @return The current timepoint as a `uint48`.
    function clock() public view virtual returns (uint48) {
        return SafeCast.toUint48(block.timestamp);
    }

    /// @dev Returns a machine-readable description of the clock source and mode.
    /// @return A string describing the clock mode (e.g., "mode=timestamp").
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory) {
        return "mode=timestamp";
    }

    // -- View Functions --

    /// @inheritdoc ISMARTHistoricalBalances
    function balanceOfAt(address account, uint256 timepoint) public view virtual override returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert FutureLookup(timepoint, currentTimepoint);
        }
        return _balanceCheckpoints[account].upperLookupRecent(SafeCast.toUint48(timepoint));
    }

    /// @inheritdoc ISMARTHistoricalBalances
    function totalSupplyAt(uint256 timepoint) public view virtual override returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert FutureLookup(timepoint, currentTimepoint);
        }
        return _totalSupplyCheckpoints.upperLookupRecent(SafeCast.toUint48(timepoint));
    }

    // -- Hooks Logic (Internal Implementation for SMARTHooks) --

    /// @dev Internal logic executed after a mint operation to update historical total supply and recipient's balance.
    ///      This function is intended to be called by the `_afterMint` hook in the inheriting contract.
    /// @param to The address that received the minted tokens.
    /// @param amount The amount of tokens minted.
    function __historical_balances_afterMintLogic(address to, uint256 amount) internal virtual {
        uint208 castAmount = SafeCast.toUint208(amount);

        _writeCheckpointAdd(_totalSupplyCheckpoints, castAmount);
        (uint208 previousValue, uint208 newValue) = _writeCheckpointAdd(_balanceCheckpoints[to], castAmount);
        emit CheckpointUpdated(_smartSender(), to, previousValue, newValue);
    }

    /// @dev Internal logic executed after a burn operation to update historical total supply and burner's balance.
    ///      This function is intended to be called by the `_afterBurn` hook in the inheriting contract.
    /// @param from The address whose tokens were burned.
    /// @param amount The amount of tokens burned.
    function __historical_balances_afterBurnLogic(address from, uint256 amount) internal virtual {
        uint208 castAmount = SafeCast.toUint208(amount);

        _writeCheckpointSubtract(_totalSupplyCheckpoints, castAmount);
        (uint208 previousValue, uint208 newValue) = _writeCheckpointSubtract(_balanceCheckpoints[from], castAmount);
        emit CheckpointUpdated(_smartSender(), from, previousValue, newValue);
    }

    /// @dev Internal logic executed after a transfer operation to update historical balances of the sender and
    /// recipient.
    ///      This function is intended to be called by the `_afterTransfer` hook in the inheriting contract.
    /// @param from The address that sent the tokens.
    /// @param to The address that received the tokens.
    /// @param amount The amount of tokens transferred.
    function __historical_balances_afterTransferLogic(address from, address to, uint256 amount) internal virtual {
        uint208 castAmount = SafeCast.toUint208(amount);
        address sender = _smartSender();

        (uint208 previousValue, uint208 newValue) = _writeCheckpointSubtract(_balanceCheckpoints[from], castAmount);
        emit CheckpointUpdated(sender, from, previousValue, newValue);
        (previousValue, newValue) = _writeCheckpointAdd(_balanceCheckpoints[to], castAmount);
        emit CheckpointUpdated(sender, to, previousValue, newValue);
    }

    // -- Internal Functions --

    /// @dev Writes a new checkpoint to a `Checkpoints.Trace208` storage by adding a delta.
    /// @param store A storage pointer to the `Checkpoints.Trace208` struct.
    /// @param delta The change in value to be added.
    /// @return previousValue The value before this update.
    /// @return newValue The value after this update.
    function _writeCheckpointAdd(
        Checkpoints.Trace208 storage store,
        uint208 delta
    )
        private
        returns (uint208 previousValue, uint208 newValue)
    {
        previousValue = store.latest();
        // Solidity 0.8+ handles overflow checks automatically
        newValue = previousValue + delta;
        store.push(clock(), newValue);
        return (previousValue, newValue);
    }

    /// @dev Writes a new checkpoint to a `Checkpoints.Trace208` storage by subtracting a delta.
    /// @param store A storage pointer to the `Checkpoints.Trace208` struct.
    /// @param delta The change in value to be subtracted.
    /// @return previousValue The value before this update.
    /// @return newValue The value after this update.
    function _writeCheckpointSubtract(
        Checkpoints.Trace208 storage store,
        uint208 delta
    )
        private
        returns (uint208 previousValue, uint208 newValue)
    {
        previousValue = store.latest();
        // Solidity 0.8+ handles underflow checks automatically
        newValue = previousValue - delta;
        store.push(clock(), newValue);
        return (previousValue, newValue);
    }
}
