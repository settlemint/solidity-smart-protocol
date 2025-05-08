// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// -- Errors --
error FreezeAmountExceedsAvailableBalance(uint256 available, uint256 requested);
error InsufficientFrozenTokens(uint256 frozenBalance, uint256 requested);
error InconsistentForcedTransferState();
error NoTokensToRecover();
error RecoveryWalletsNotVerified();
error RecoveryTargetAddressFrozen();
error RecipientAddressFrozen();
error SenderAddressFrozen();
