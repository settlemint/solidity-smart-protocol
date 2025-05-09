// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTCustodian {
    /// @notice Freezes or unfreezes an entire address.
    /// @dev Requires authorization via `_authorizeFreezeAddress`.
    /// @param userAddress The target address.
    /// @param freeze True to freeze, false to unfreeze.
    function setAddressFrozen(address userAddress, bool freeze) external;

    /// @notice Freezes a specific amount of tokens for an address.
    /// @dev Requires authorization via `_authorizeFreezePartialTokens`.
    ///      Reverts if the amount exceeds the available (unfrozen) balance.
    /// @param userAddress The target address.
    /// @param amount The amount of tokens to freeze.
    function freezePartialTokens(address userAddress, uint256 amount) external;

    /// @notice Unfreezes a specific amount of tokens for an address.
    /// @dev Requires authorization via `_authorizeFreezePartialTokens` (or a dedicated unfreeze role if needed).
    ///      Reverts if the amount exceeds the currently frozen token amount.
    /// @param userAddress The target address.
    /// @param amount The amount of tokens to unfreeze.
    function unfreezePartialTokens(address userAddress, uint256 amount) external;

    /// @notice Freezes or unfreezes multiple addresses in a batch.
    /// @dev Requires authorization via `_authorizeFreezeAddress` for each operation.
    /// @param userAddresses List of target addresses.
    /// @param freeze List of corresponding freeze statuses (true/false).
    function batchSetAddressFrozen(address[] calldata userAddresses, bool[] calldata freeze) external;

    /// @notice Freezes specific amounts of tokens for multiple addresses in a batch.
    /// @dev Requires authorization via `_authorizeFreezePartialTokens` for each operation.
    /// @param userAddresses List of target addresses.
    /// @param amounts List of corresponding amounts to freeze.
    function batchFreezePartialTokens(address[] calldata userAddresses, uint256[] calldata amounts) external;

    /// @notice Unfreezes specific amounts of tokens for multiple addresses in a batch.
    /// @dev Requires authorization via `_authorizeFreezePartialTokens` (or dedicated unfreeze role) for each operation.
    /// @param userAddresses List of target addresses.
    /// @param amounts List of corresponding amounts to unfreeze.
    function batchUnfreezePartialTokens(address[] calldata userAddresses, uint256[] calldata amounts) external;

    /// @notice Forcefully transfers tokens from one address to another, bypassing standard checks.
    /// @dev Requires authorization via `_authorizeForcedTransfer`.
    ///      Can transfer frozen tokens by automatically unfreezing the required amount.
    ///      Uses `__isForcedUpdate` flag to bypass hooks during the internal transfer.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount to transfer.
    /// @return True upon successful execution.
    function forcedTransfer(address from, address to, uint256 amount) external returns (bool);

    /// @notice Forcefully transfers tokens for multiple address pairs in a batch.
    /// @dev Requires authorization via `_authorizeForcedTransfer` for the batch operation.
    /// @param fromList List of sender addresses.
    /// @param toList List of recipient addresses.
    /// @param amounts List of corresponding amounts to transfer.
    function batchForcedTransfer(
        address[] calldata fromList,
        address[] calldata toList,
        uint256[] calldata amounts
    )
        external;

    /// @notice Recovers assets from a lost wallet to a new wallet associated with the same verified identity.
    /// @dev Requires authorization via `_authorizeRecoveryAddress`.
    ///      Requires the `investorOnchainID` to be valid and associated with both wallets (or registers the new one).
    ///      Requires the token contract to have `REGISTRAR_ROLE` on the `IdentityRegistry`.
    ///      Transfers full balance, frozen status, and partially frozen amount.
    ///      Uses `__isForcedUpdate` flag to bypass hooks during the internal transfer.
    /// @param lostWallet The compromised or inaccessible wallet address.
    /// @param newWallet The target wallet address for recovery.
    /// @param investorOnchainID The on-chain ID contract address of the investor.
    /// @return True upon successful execution.
    function recoveryAddress(
        address lostWallet,
        address newWallet,
        address investorOnchainID
    )
        external
        returns (bool);

    // -- View Functions --

    /// @notice Checks if an address is fully frozen.
    /// @param userAddress The address to check.
    /// @return True if the address is frozen, false otherwise.
    function isFrozen(address userAddress) external view returns (bool);

    /// @notice Gets the amount of tokens specifically frozen for an address.
    /// @param userAddress The address to check.
    /// @return The amount of frozen tokens.
    function getFrozenTokens(address userAddress) external view returns (uint256);
}
