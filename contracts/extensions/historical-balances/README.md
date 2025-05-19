# SMART Historical Balances Extension

This extension allows a SMART token to track and query historical token balances for individual accounts and the historical total supply of the token at different points in time (block numbers).

## Overview

The Historical Balances extension provides a standardized way to record snapshots of balances and total supply whenever they change due to minting, burning, or transferring tokens. This enables on-chain lookups of past states, which can be useful for various purposes such as calculating voting power at a specific block, distributing rewards based on past holdings, or for auditing and analysis.

Key components include:

- **`_SMARTHistoricalBalancesLogic.sol`**: An internal abstract contract containing the core logic for checkpointing balances and total supply using OpenZeppelin's `Checkpoints` library. It provides the `balanceOfAt(address, uint256)` and `totalSupplyAt(uint256)` view functions, and defines the internal logic functions (`_historical_balances_afterMintLogic`, `_historical_balances_afterBurnLogic`, `_historical_balances_afterTransferLogic`) that are hooked into the token's operations.
- **`SMARTHistoricalBalances.sol`**: The standard (non-upgradeable) implementation. It inherits `_SMARTHistoricalBalancesLogic`, `Context`, and `SMARTExtension`. It overrides the `_afterMint`, `_afterBurn`, and `_afterTransfer` SMARTHooks to call the respective logic functions from `_SMARTHistoricalBalancesLogic`.
- **`SMARTHistoricalBalancesUpgradeable.sol`**: The upgradeable implementation. It inherits `_SMARTHistoricalBalancesLogic`, `ContextUpgradeable`, `SMARTExtensionUpgradeable`, and `Initializable`. It provides the same hook overrides as the standard version and includes an initializer `__SMARTHistoricalBalances_init`.

## Features

- **Historical Account Balances**: Retrieve the token balance of any account at a past block number using `balanceOfAt(address account, uint256 timepoint)`.
- **Historical Total Supply**: Retrieve the total token supply at a past block number using `totalSupplyAt(uint256 timepoint)`.
- **Timekeeping**: Uses a `clock()` function (defaults to `block.number`) to timestamp checkpoints. The `CLOCK_MODE()` function provides a machine-readable description of this clock.
- **Automatic Checkpointing**: Automatically creates checkpoints for account balances and total supply after mint, burn, and transfer operations by hooking into the respective `_afterMint`, `_afterBurn`, and `_afterTransfer` SMARTHooks.
- **Standard & Upgradeable**: Provides both standard and upgradeable versions for flexible integration.
- **Error Handling**: Reverts with a `FutureLookup` error if a query is made for a timepoint in the future.

## Usage

To use this extension:

1. **Inherit Base Contracts**:

   - Inherit the core `SMART` or `SMARTUpgradeable` implementation.
   - Inherit the corresponding historical balances implementation (`SMARTHistoricalBalances` or `SMARTHistoricalBalancesUpgradeable`).
   - Ensure necessary base contracts (e.g., `ERC20`/`ERC20Upgradeable`, `Context`/`ContextUpgradeable`, `SMARTExtension`/`SMARTExtensionUpgradeable`) are also inherited by your final token contract.

2. **Implement Constructor/Initializer**:

   - **Standard (`SMARTHistoricalBalances`)**: Ensure parent constructors (like `SMART`) are called in the final contract's `constructor`.
   - **Upgradeable (`SMARTHistoricalBalancesUpgradeable`)**: In the final contract's `initialize` function, ensure parent initializers (e.g., `__ERC20_init`, `__SMART_init`, `__SMART_init_extensions`) are called. Then, call `__SMARTHistoricalBalances_init()` as part of the extension initialization process (typically handled by `__SMART_init_extensions` if this extension is registered).

3. **Hook Integration**: The extension automatically hooks into `_afterMint`, `_afterBurn`, and `_afterTransfer`. No further manual hook setup is generally required for its core functionality.

## Authorization

This extension does **not** implement specific authorization roles for its view functions (`balanceOfAt`, `totalSupplyAt`), which are public. The creation of checkpoints is tied to the `mint`, `burn`, and `transfer` operations, so the authorization for those operations (defined in your base token and other extensions like Custodian or Minter) implicitly controls when checkpoints are recorded.

## Security Considerations

- **Gas Costs**: Storing checkpoints consumes gas. Frequent mints, burns, or transfers, especially involving many unique addresses, can lead to increased gas costs for these operations. Consider the trade-off between the utility of historical data and the operational gas costs.
- **Timepoint Accuracy**: The default `clock()` uses `block.number`. Be aware of the implications if a different time source is used (e.g., `block.timestamp`).
- **Data Growth**: Checkpoint data is stored on-chain and will grow over time. While OpenZeppelin's `Checkpoints` library is efficient, extremely high transaction volumes over a long period could lead to a large state size for the contract.
- **Future Lookups**: The `balanceOfAt` and `totalSupplyAt` functions correctly revert if a future timepoint is queried, preventing invalid data retrieval.

This extension leverages OpenZeppelin's `Checkpoints.sol` library, which is well-audited and widely used.
