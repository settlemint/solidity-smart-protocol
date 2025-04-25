// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

// Interface imports
import { ISMARTIdentityRegistry } from "../../../interface/ISMARTIdentityRegistry.sol";
import { IIdentity } from "../../../../onchainid/interface/IIdentity.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";

// Internal implementation imports
import { _SMARTCustodianAuthorizationHooks } from "./_SMARTCustodianAuthorizationHooks.sol";

// Common errors
import { LengthMismatch } from "./../../common/CommonErrors.sol";

/// @title Internal Logic for SMART Custodian Extension
/// @notice Base contract containing the core state, logic, events, and authorization hooks for custodian features.
/// @dev This abstract contract is intended to be inherited by both standard (SMARTCustodian) and upgradeable
///      (SMARTCustodianUpgradeable) implementations. It defines shared state, logic, and hooks.
abstract contract _SMARTCustodianLogic is _SMARTExtension, _SMARTCustodianAuthorizationHooks {
    // -- Storage Variables --
    /// @notice Mapping from address to its frozen status (true if frozen, false otherwise).
    mapping(address => bool) internal __frozen;
    /// @notice Mapping from address to the amount of tokens specifically frozen for that address.
    mapping(address => uint256) internal __frozenTokens;

    // -- Errors --
    error FreezeAmountExceedsAvailableBalance(uint256 available, uint256 requested);
    error InsufficientFrozenTokens(uint256 frozenBalance, uint256 requested);
    error InconsistentForcedTransferState();
    error NoTokensToRecover();
    error RecoveryWalletsNotVerified();
    error RecoveryTargetAddressFrozen();
    error RecipientAddressFrozen();
    error SenderAddressFrozen();

    // -- Events --
    /// @notice Emitted when an address's full frozen status is changed.
    /// @param userAddress The address whose status changed.
    /// @param isFrozen The new frozen status (true if frozen, false if unfrozen).
    event AddressFrozen(address indexed userAddress, bool indexed isFrozen);

    /// @notice Emitted when assets are successfully recovered from a lost wallet to a new one.
    /// @param lostWallet The address from which assets were recovered.
    /// @param newWallet The address to which assets were transferred.
    /// @param investorOnchainID The on-chain ID associated with the investor.
    event RecoverySuccess(address indexed lostWallet, address indexed newWallet, address indexed investorOnchainID);

    /// @notice Emitted when a specific amount of tokens is frozen for an address.
    /// @param user The address for which tokens were frozen.
    /// @param amount The amount of tokens frozen.
    event TokensFrozen(address indexed user, uint256 amount);

    /// @notice Emitted when a specific amount of tokens is unfrozen for an address.
    /// @param user The address for which tokens were unfrozen.
    /// @param amount The amount of tokens unfrozen.
    event TokensUnfrozen(address indexed user, uint256 amount);

    // -- Abstract Functions (Dependencies) --

    /// @notice Abstract function to retrieve the token balance of an account.
    /// @dev Must be implemented by inheriting contracts to call the appropriate balance function (e.g.,
    /// ERC20/ERC20Upgradeable.balanceOf).
    /// @param account The address whose balance is queried.
    /// @return The token balance of the account.
    function _getBalance(address account) internal view virtual returns (uint256);

    /// @notice Abstract function to execute the underlying token transfer logic.
    /// @dev Must be implemented by inheriting contracts to call the appropriate update/transfer function (e.g.,
    /// ERC20/ERC20Upgradeable._update).
    /// @param from The sender address.
    /// @param to The recipient address.
    /// @param amount The amount to transfer.
    function _executeTransferUpdate(address from, address to, uint256 amount) internal virtual;

    // -- State-Changing Functions (Admin/Authorized) --

    /// @notice Freezes or unfreezes an entire address.
    /// @dev Requires authorization via `_authorizeFreezeAddress`.
    /// @param userAddress The target address.
    /// @param freeze True to freeze, false to unfreeze.
    function setAddressFrozen(address userAddress, bool freeze) external virtual {
        _setAddressFrozen(userAddress, freeze);
    }

    /// @notice Freezes a specific amount of tokens for an address.
    /// @dev Requires authorization via `_authorizeFreezePartialTokens`.
    ///      Reverts if the amount exceeds the available (unfrozen) balance.
    /// @param userAddress The target address.
    /// @param amount The amount of tokens to freeze.
    function freezePartialTokens(address userAddress, uint256 amount) external virtual {
        _freezePartialTokens(userAddress, amount);
    }

    /// @notice Unfreezes a specific amount of tokens for an address.
    /// @dev Requires authorization via `_authorizeFreezePartialTokens` (or a dedicated unfreeze role if needed).
    ///      Reverts if the amount exceeds the currently frozen token amount.
    /// @param userAddress The target address.
    /// @param amount The amount of tokens to unfreeze.
    function unfreezePartialTokens(address userAddress, uint256 amount) external virtual {
        // Consider if unfreezing should use the same role as freezing or a different one.
        // Using _authorizeFreezePartialTokens for now, adjust if separate permission is needed.
        _authorizeFreezePartialTokens();
        _unfreezePartialTokensLogic(userAddress, amount);
    }

    /// @notice Freezes or unfreezes multiple addresses in a batch.
    /// @dev Requires authorization via `_authorizeFreezeAddress` for each operation.
    /// @param userAddresses List of target addresses.
    /// @param freeze List of corresponding freeze statuses (true/false).
    function batchSetAddressFrozen(address[] calldata userAddresses, bool[] calldata freeze) external virtual {
        if (userAddresses.length != freeze.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _setAddressFrozen(userAddresses[i], freeze[i]);
        }
    }

    /// @notice Freezes specific amounts of tokens for multiple addresses in a batch.
    /// @dev Requires authorization via `_authorizeFreezePartialTokens` for each operation.
    /// @param userAddresses List of target addresses.
    /// @param amounts List of corresponding amounts to freeze.
    function batchFreezePartialTokens(address[] calldata userAddresses, uint256[] calldata amounts) external virtual {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _freezePartialTokens(userAddresses[i], amounts[i]);
        }
    }

    /// @notice Unfreezes specific amounts of tokens for multiple addresses in a batch.
    /// @dev Requires authorization via `_authorizeFreezePartialTokens` (or dedicated unfreeze role) for each operation.
    /// @param userAddresses List of target addresses.
    /// @param amounts List of corresponding amounts to unfreeze.
    function batchUnfreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        external
        virtual
    {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        // Consider if unfreezing should use the same role as freezing or a different one.
        _authorizeFreezePartialTokens(); // Check auth once for the batch
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _unfreezePartialTokensLogic(userAddresses[i], amounts[i]);
        }
    }

    /// @notice Forcefully transfers tokens from one address to another, bypassing standard checks.
    /// @dev Requires authorization via `_authorizeForcedTransfer`.
    ///      Can transfer frozen tokens by automatically unfreezing the required amount.
    ///      Uses `__isForcedUpdate` flag to bypass hooks during the internal transfer.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount to transfer.
    /// @return True upon successful execution.
    function forcedTransfer(address from, address to, uint256 amount) external virtual returns (bool) {
        _forcedTransfer(from, to, amount);
        return true;
    }

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
        external
        virtual
    {
        if (!((fromList.length == toList.length) && (toList.length == amounts.length))) {
            revert LengthMismatch();
        }
        _authorizeForcedTransfer(); // Check auth once for the batch
        for (uint256 i = 0; i < fromList.length; i++) {
            // Call internal logic directly for efficiency within the loop
            _forcedTransferLogic(fromList[i], toList[i], amounts[i]);
        }
    }

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
        virtual
        returns (bool)
    {
        _recoveryAddress(lostWallet, newWallet, investorOnchainID);
        return true;
    }

    // -- View Functions --

    /// @notice Checks if an address is fully frozen.
    /// @param userAddress The address to check.
    /// @return True if the address is frozen, false otherwise.
    function isFrozen(address userAddress) external view virtual returns (bool) {
        return __frozen[userAddress];
    }

    /// @notice Gets the amount of tokens specifically frozen for an address.
    /// @param userAddress The address to check.
    /// @return The amount of frozen tokens.
    function getFrozenTokens(address userAddress) external view virtual returns (uint256) {
        return __frozenTokens[userAddress];
    }

    // -- Internal Functions --

    /// @dev Internal logic to set the frozen status of an address.
    function _setAddressFrozen(address userAddress, bool freeze) internal virtual {
        _authorizeFreezeAddress();
        __frozen[userAddress] = freeze;
        emit AddressFrozen(userAddress, freeze);
    }

    /// @dev Internal logic to freeze a partial amount of tokens.
    function _freezePartialTokens(address userAddress, uint256 amount) internal virtual {
        _authorizeFreezePartialTokens();
        uint256 currentFrozen = __frozenTokens[userAddress];
        uint256 availableBalance = _getBalance(userAddress) - currentFrozen;
        if (availableBalance < amount) {
            revert FreezeAmountExceedsAvailableBalance(availableBalance, amount);
        }
        __frozenTokens[userAddress] = currentFrozen + amount;
        emit TokensFrozen(userAddress, amount);
    }

    /// @dev Internal core logic to unfreeze a partial amount of tokens (without auth check).
    function _unfreezePartialTokensLogic(address userAddress, uint256 amount) internal virtual {
        uint256 currentFrozen = __frozenTokens[userAddress];
        if (currentFrozen < amount) {
            revert InsufficientFrozenTokens(currentFrozen, amount);
        }
        __frozenTokens[userAddress] = currentFrozen - amount;
        emit TokensUnfrozen(userAddress, amount);
    }

    /// @dev Internal logic wrapper for a single forced transfer.
    function _forcedTransfer(address from, address to, uint256 amount) internal virtual {
        _authorizeForcedTransfer();
        _forcedTransferLogic(from, to, amount);
    }

    /// @dev Internal core logic for a single forced transfer (without auth check).
    function _forcedTransferLogic(address from, address to, uint256 amount) internal virtual {
        // Note: Core validation (frozen checks) should ideally happen *before* calling this,
        // potentially in overridden _beforeTransfer hooks, but forcedTransfer bypasses those.
        // Direct balance check is necessary here.
        uint256 currentBalance = _getBalance(from);
        if (currentBalance < amount) revert IERC20Errors.ERC20InsufficientBalance(from, currentBalance, amount);

        // Unfreeze tokens if needed
        uint256 currentFrozen = __frozenTokens[from];
        if (currentFrozen > 0) {
            uint256 freeBalance = currentBalance - currentFrozen;
            if (amount > freeBalance) {
                uint256 neededFromFrozen = amount - freeBalance;
                __frozenTokens[from] = currentFrozen - neededFromFrozen;
                emit TokensUnfrozen(from, neededFromFrozen);
            }
        }

        // Execute transfer bypassing hooks
        __isForcedUpdate = true;
        _executeTransferUpdate(from, to, amount);
        __isForcedUpdate = false;
    }

    /// @dev Internal logic wrapper for address recovery.
    function _recoveryAddress(address lostWallet, address newWallet, address investorOnchainID) internal virtual {
        _authorizeRecoveryAddress();
        _recoveryAddressLogic(lostWallet, newWallet, investorOnchainID);
    }

    /// @dev Internal core logic for address recovery (without auth check).
    function _recoveryAddressLogic(address lostWallet, address newWallet, address investorOnchainID) internal virtual {
        uint256 balance = _getBalance(lostWallet);
        if (balance == 0) revert NoTokensToRecover();

        ISMARTIdentityRegistry registry = this.identityRegistry();
        // Assumes core logic provides requiredClaimTopics or we fetch them if needed
        uint256[] memory topics = this.requiredClaimTopics();
        bool lostWalletVerified = registry.isVerified(lostWallet, topics);
        bool newWalletVerified = registry.isVerified(newWallet, topics);

        // Require at least one wallet to be verified initially.
        // The registry interaction below handles ensuring both are linked or the new one is registered.
        if (!lostWalletVerified && !newWalletVerified) {
            revert RecoveryWalletsNotVerified();
        }
        if (__frozen[newWallet]) revert RecoveryTargetAddressFrozen();

        uint256 frozenTokens = __frozenTokens[lostWallet];
        bool walletFrozen = __frozen[lostWallet];

        // Execute transfer bypassing hooks
        __isForcedUpdate = true;
        _executeTransferUpdate(lostWallet, newWallet, balance);
        __isForcedUpdate = false;

        // Transfer frozen tokens state
        if (frozenTokens > 0) {
            emit TokensUnfrozen(lostWallet, frozenTokens);
            __frozenTokens[lostWallet] = 0;
            __frozenTokens[newWallet] = frozenTokens;
            emit TokensFrozen(newWallet, frozenTokens);
        }

        // Transfer frozen status state
        if (walletFrozen) {
            __frozen[newWallet] = true;
            __frozen[lostWallet] = false; // Ensure old wallet is unfrozen
            emit AddressFrozen(newWallet, true);
            emit AddressFrozen(lostWallet, false);
        } else if (__frozen[newWallet]) {
            // Defensive: Ensure new wallet isn't incorrectly marked frozen if old wasn't
            __frozen[newWallet] = false;
            emit AddressFrozen(newWallet, false);
        }

        // Update identity registry (Requires REGISTRAR_ROLE)
        if (lostWalletVerified) {
            uint16 country = registry.investorCountry(lostWallet);
            // If new wallet isn't verified, register it with the details from the lost wallet.
            if (!newWalletVerified) {
                // This assumes the investorOnchainID contract is valid and owned by the investor.
                registry.registerIdentity(newWallet, IIdentity(investorOnchainID), country);
            }
            // Delete the old identity registration.
            registry.deleteIdentity(lostWallet);
        } else {
            // If lost wallet wasn't verified, but new one is, we don't need to do anything
            // If neither were verified initially, this state is unreachable due to the check above.
        }

        emit RecoverySuccess(lostWallet, newWallet, investorOnchainID);
    }

    // -- Internal Hook Helper Functions --

    /// @notice Internal logic executed before a mint operation to check recipient freeze status.
    /// @dev Called by the implementing contract's `_beforeMint` hook.
    /// @param to The recipient address.
    //  Note: amount parameter is unused in this specific hook implementation.
    function _custodian_beforeMintLogic(address to, uint256 /* amount */ ) internal view virtual {
        if (__frozen[to]) revert RecipientAddressFrozen();
    }

    /// @notice Internal logic executed before a transfer to check sender/recipient freeze status and available balance.
    /// @dev Called by the implementing contract's `_beforeTransfer` hook.
    /// @param from The sender address.
    /// @param to The recipient address.
    /// @param amount The amount being transferred.
    function _custodian_beforeTransferLogic(address from, address to, uint256 amount) internal view virtual {
        if (__frozen[from]) revert SenderAddressFrozen();
        if (__frozen[to]) revert RecipientAddressFrozen();

        uint256 frozenTokens = __frozenTokens[from];
        // Check against available *unfrozen* balance
        uint256 availableUnfrozen = _getBalance(from) - frozenTokens;
        if (availableUnfrozen < amount) {
            // Revert using standard ERC20 error for insufficient balance (considering frozen amount)
            revert IERC20Errors.ERC20InsufficientBalance(from, availableUnfrozen, amount);
        }
    }

    /// @notice Internal logic executed before a burn operation (typically admin-initiated).
    /// @dev Checks total balance and automatically unfreezes tokens if the burn amount exceeds the free balance.
    ///      Called by the implementing contract's `_beforeBurn` hook.
    /// @param from The address whose tokens are being burned.
    /// @param amount The amount being burned.
    function _custodian_beforeBurnLogic(address from, uint256 amount) internal virtual {
        // Note: Burn operation itself needs authorization (e.g., BURNER_ROLE) handled elsewhere.
        uint256 totalBalance = _getBalance(from);
        if (totalBalance < amount) {
            revert IERC20Errors.ERC20InsufficientBalance(from, totalBalance, amount);
        }

        uint256 currentFrozen = __frozenTokens[from];
        if (currentFrozen > 0) {
            uint256 freeBalance = totalBalance - currentFrozen;
            if (amount > freeBalance) {
                // Amount requires dipping into frozen tokens, so unfreeze the difference.
                uint256 tokensToUnfreeze = amount - freeBalance;
                // The total balance check above ensures currentFrozen >= tokensToUnfreeze
                _unfreezePartialTokensLogic(from, tokensToUnfreeze); // Use internal logic directly
            }
        }
        // The actual _burn should occur after this hook in the inheriting contract.
    }

    /// @notice Internal logic executed before a redeem operation (typically user-initiated).
    /// @dev Checks sender freeze status and ensures enough *unfrozen* balance is available.
    ///      Called by the implementing contract's `_beforeRedeem` hook.
    /// @param from The address redeeming tokens.
    /// @param amount The amount being redeemed.
    function _custodian_beforeRedeemLogic(address from, uint256 amount) internal view virtual {
        if (__frozen[from]) revert SenderAddressFrozen();

        uint256 frozenTokens = __frozenTokens[from];
        uint256 availableUnfrozen = _getBalance(from) - frozenTokens;
        if (availableUnfrozen < amount) {
            revert IERC20Errors.ERC20InsufficientBalance(from, availableUnfrozen, amount);
        }
    }
}
