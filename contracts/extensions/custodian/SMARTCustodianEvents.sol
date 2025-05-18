// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title Events for SMART Custodian Extension
/// @notice Defines events emitted by the custodian extension to log significant actions like freezing,
///         recovery, and changes to token freeze amounts.
/// @dev Events are crucial for off-chain applications to track and react to on-chain custodian operations.
///      `indexed` parameters allow for efficient filtering of these event logs.

/// @notice Emitted when an address's full frozen status (i.e., the entire address is frozen or unfrozen)
///         is changed by an authorized custodian.
/// @param sender The address (e.g., custodian, admin) that initiated the freeze/unfreeze operation.
///               `indexed` for easier filtering of operations by a specific admin.
/// @param userAddress The address whose frozen status was changed. `indexed` for tracking a specific user.
/// @param isFrozen The new frozen status: `true` if the address is now frozen, `false` if unfrozen.
///                 `indexed` to quickly find all freeze or unfreeze events.
event AddressFrozen(address indexed sender, address indexed userAddress, bool indexed isFrozen);

/// @notice Emitted when assets are successfully recovered from a lost or compromised wallet to a new wallet
///         belonging to the same verified identity.
/// @param sender The address (e.g., custodian) that initiated the recovery operation. `indexed`.
/// @param lostWallet The address from which assets were recovered. `indexed`.
/// @param newWallet The address to which assets were transferred and identity re-associated. `indexed`.
/// @param investorOnchainID The on-chain ID contract address that links the `lostWallet` and `newWallet`,
///                          confirming they belong to the same beneficial owner.
///                          Not typically indexed as it might be a shared contract for many users.
event RecoverySuccess(
    address indexed sender, address indexed lostWallet, address indexed newWallet, address investorOnchainID
);

/// @notice Emitted when a specific amount of tokens is partially frozen for an address.
/// @dev This refers to freezing a portion of an address's tokens, distinct from freezing the entire address.
/// @param sender The address that initiated the partial freeze operation. `indexed`.
/// @param user The address for which a specific amount of tokens was frozen. `indexed`.
/// @param amount The quantity of tokens that were specifically frozen.
event TokensFrozen(address indexed sender, address indexed user, uint256 amount);

/// @notice Emitted when a specific amount of previously partially frozen tokens is unfrozen for an address.
/// @param sender The address that initiated the partial unfreeze operation. `indexed`.
/// @param user The address for which a specific amount of tokens was unfrozen. `indexed`.
/// @param amount The quantity of tokens that were unfrozen from the partial freeze.
event TokensUnfrozen(address indexed sender, address indexed user, uint256 amount);
