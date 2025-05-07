// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
import { SMARTHooks } from "./../../common/SMARTHooks.sol";
import { FutureLookup } from "./../SMARTHistoricalBalancesErrors.sol";
import { ISMARTHistoricalBalances } from "./../ISMARTHistoricalBalances.sol";

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
    mapping(address account => Checkpoints.Trace208) private _balanceCheckpoints;

    // Track historical total supply
    Checkpoints.Trace208 private _totalSupplyCheckpoints;

    // -- Events --

    /**
     * @dev Emitted when a balance checkpoint is created for an account or for the total supply.
     * @param account The account for which a balance checkpoint was created. If address(0), it's a total supply
     * checkpoint.
     * @param oldBalance The balance before the operation that triggered the checkpoint.
     * @param newBalance The balance after the operation that triggered the checkpoint.
     */
    event CheckpointUpdated(address indexed account, uint256 oldBalance, uint256 newBalance);
    // Note: Original 'CheckpointCreated' event was less descriptive. 'CheckpointUpdated' might be more suitable,
    // or we could have separate events if needed. For now, let's refine the existing one if it's used,
    // or consider if it's truly necessary given OpenZeppelin's Checkpoints doesn't emit events on push.
    // This event is not actually emitted in the provided code. Removing for now to align with OZ Checkpoints.
    // If explicit eventing is desired, it needs to be added to the _push or logic functions.

    // -- Timekeeping --

    /**
     * @dev Returns the current timepoint used for timestamping checkpoints.
     *      By default, this is the current block number.
     * @return The current timepoint as a `uint48`.
     */
    function clock() public view virtual returns (uint48) {
        return Time.blockNumber();
    }

    /**
     * @dev Returns a machine-readable description of the clock source and mode.
     * @return A string describing the clock mode (e.g., "mode=blocknumber&from=default").
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory) {
        return "mode=blocknumber&from=default";
    }

    // -- View Functions --

    /**
     * @dev Returns the token balance of a specific `account` at a given `timepoint`.
     * @param account The address of the account to query.
     * @param timepoint The timepoint (e.g., block number) at which to retrieve the balance.
     * @return The token balance of `account` at `timepoint`.
     */
    function balanceOfAt(address account, uint256 timepoint) public view virtual returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert FutureLookup(timepoint, currentTimepoint);
        }
        return _balanceCheckpoints[account].upperLookupRecent(SafeCast.toUint48(timepoint));
    }

    /**
     * @dev Returns the total token supply at a given `timepoint`.
     * @param timepoint The timepoint (e.g., block number) at which to retrieve the total supply.
     * @return The total token supply at `timepoint`.
     */
    function totalSupplyAt(uint256 timepoint) public view virtual returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert FutureLookup(timepoint, currentTimepoint);
        }
        return _totalSupplyCheckpoints.upperLookupRecent(SafeCast.toUint48(timepoint));
    }

    // -- Internal Functions --

    /**
     * @dev Pushes a new checkpoint to a `Checkpoints.Trace208` storage.
     *      It calculates the new value using the provided operation `op` and `delta`.
     * @param store A storage pointer to the `Checkpoints.Trace208` struct.
     * @param op A function pointer that takes the latest checkpoint value and `delta`, and returns the new value.
     * @param delta The change in value to be applied by the `op` function.
     * @return previousValue The value before this push.
     * @return newValue The value after this push.
     */
    function _push(
        Checkpoints.Trace208 storage store,
        function(uint208, uint208) view returns (uint208) op,
        uint208 delta
    )
        private
        returns (uint208 previousValue, uint208 newValue)
    {
        // Capture previous value before push
        previousValue = store.latest();
        // Push the new value
        newValue = op(previousValue, delta);
        store.push(clock(), newValue);
        // Note: Event emission for CheckpointUpdated could be added here if desired.
        // e.g., emit CheckpointUpdated(account, previousValue, newValue);
        // However, determining 'account' here is tricky as this is a generic push.
        // Event emission is better handled in the specific logic functions (_historical_balances_afterMintLogic, etc.)
        return (previousValue, newValue);
    }

    /**
     * @dev Internal pure function to add two `uint208` numbers. Used by `_push`.
     * @param a The first number.
     * @param b The second number.
     * @return The sum of `a` and `b`.
     */
    function _add(uint208 a, uint208 b) private pure returns (uint208) {
        return a + b;
    }

    /**
     * @dev Internal pure function to subtract one `uint208` number from another. Used by `_push`.
     * @param a The number to subtract from.
     * @param b The number to subtract.
     * @return The result of `a - b`.
     */
    function _subtract(uint208 a, uint208 b) private pure returns (uint208) {
        return a - b;
    }

    // -- Hooks Logic (Internal Implementation for SMARTHooks) --

    /// @dev Internal logic executed after a mint operation to update historical total supply and recipient's balance.
    ///      This function is intended to be called by the `_afterMint` hook in the inheriting contract.
    /// @param to The address that received the minted tokens.
    /// @param amount The amount of tokens minted.
    function _historical_balances_afterMintLogic(address to, uint256 amount) internal virtual {
        uint208 castAmount = SafeCast.toUint208(amount);

        _push(_totalSupplyCheckpoints, _add, castAmount);
        _push(_balanceCheckpoints[to], _add, castAmount);
    }

    /// @dev Internal logic executed after a burn operation to update historical total supply and burner's balance.
    ///      This function is intended to be called by the `_afterBurn` hook in the inheriting contract.
    /// @param from The address whose tokens were burned.
    /// @param amount The amount of tokens burned.
    function _historical_balances_afterBurnLogic(address from, uint256 amount) internal virtual {
        uint208 castAmount = SafeCast.toUint208(amount);

        _push(_totalSupplyCheckpoints, _subtract, castAmount);
        _push(_balanceCheckpoints[from], _subtract, castAmount);
    }

    /// @dev Internal logic executed after a transfer operation to update historical balances of the sender and
    /// recipient.
    ///      This function is intended to be called by the `_afterTransfer` hook in the inheriting contract.
    /// @param from The address that sent the tokens.
    /// @param to The address that received the tokens.
    /// @param amount The amount of tokens transferred.
    function _historical_balances_afterTransferLogic(address from, address to, uint256 amount) internal virtual {
        uint208 castAmount = SafeCast.toUint208(amount);

        _push(_balanceCheckpoints[from], _subtract, castAmount);
        _push(_balanceCheckpoints[to], _add, castAmount);
        // emit CheckpointUpdated(to, oldBalanceTo, newBalanceTo);
    }
}
