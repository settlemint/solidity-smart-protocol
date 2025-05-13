// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

// OnchainID imports
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";

// Interface imports
import { ISMARTIdentityRegistry } from "../../../interface/ISMARTIdentityRegistry.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";

// Internal implementation imports
import { LengthMismatch } from "./../../common/CommonErrors.sol";
import {
    FreezeAmountExceedsAvailableBalance,
    InsufficientFrozenTokens,
    NoTokensToRecover,
    RecoveryWalletsNotVerified,
    RecoveryTargetAddressFrozen,
    RecipientAddressFrozen,
    SenderAddressFrozen
} from "./../SMARTCustodianErrors.sol";
import { AddressFrozen, TokensFrozen, TokensUnfrozen, RecoverySuccess } from "./../SMARTCustodianEvents.sol";
import { ISMARTCustodian } from "../ISMARTCustodian.sol";

/// @title Internal Logic for SMART Custodian Extension
/// @notice Base contract containing the core state, logic, events, and authorization hooks for custodian features.
/// @dev This abstract contract is intended to be inherited by both standard (SMARTCustodian) and upgradeable
///      (SMARTCustodianUpgradeable) implementations. It defines shared state, logic, and hooks.

abstract contract _SMARTCustodianLogic is _SMARTExtension, ISMARTCustodian {
    // -- Storage Variables --
    /// @notice Mapping from address to its frozen status (true if frozen, false otherwise).
    mapping(address => bool) internal __frozen;
    /// @notice Mapping from address to the amount of tokens specifically frozen for that address.
    mapping(address => uint256) internal __frozenTokens;

    // -- Internal Setup Function --

    /// @notice Initializes the custodian interface.
    /// @dev Stores the interface ID used to look up custodian claims. Reverts if the interface is 0.
    ///      This function should only be called once during the contract's initialization phase.
    function __SMARTCustodian_init_unchained() internal {
        _registerInterface(type(ISMARTCustodian).interfaceId);
    }

    // -- Abstract Functions (Dependencies) --

    /// @notice Abstract function to retrieve the token balance of an account.
    /// @dev Must be implemented by inheriting contracts to call the appropriate balance function (e.g.,
    /// ERC20/ERC20Upgradeable.balanceOf).
    /// @param account The address whose balance is queried.
    /// @return The token balance of the account.
    function __custodian_getBalance(address account) internal view virtual returns (uint256);

    /// @notice Abstract function to execute the underlying token transfer logic.
    /// @dev Must be implemented by inheriting contracts to call the appropriate update/transfer function (e.g.,
    /// ERC20/ERC20Upgradeable._update).
    /// @param from The sender address.
    /// @param to The recipient address.
    /// @param amount The amount to transfer.
    function __custodian_executeTransferUpdate(address from, address to, uint256 amount) internal virtual;

    // -- Internal Implementation for SMARTCustodian interface functions --

    /// @dev Internal function to set the frozen status of an address.
    /// @param userAddress The address to set the frozen status for.
    /// @param freeze The new frozen status.
    function _smart_setAddressFrozen(address userAddress, bool freeze) internal virtual {
        __frozen[userAddress] = freeze;
        emit AddressFrozen(_smartSender(), userAddress, freeze);
    }

    /// @dev Internal function to set the frozen status of multiple addresses.
    /// @param userAddresses The addresses to set the frozen status for.
    /// @param freeze The new frozen status.
    function _smart_batchSetAddressFrozen(address[] calldata userAddresses, bool[] calldata freeze) internal virtual {
        if (userAddresses.length != freeze.length) revert LengthMismatch();
        uint256 length = userAddresses.length;
        for (uint256 i = 0; i < length;) {
            _smart_setAddressFrozen(userAddresses[i], freeze[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function to freeze a partial amount of tokens for an address.
    /// @param userAddress The address to freeze the tokens for.
    /// @param amount The amount of tokens to freeze.
    function _smart_freezePartialTokens(address userAddress, uint256 amount) internal virtual {
        uint256 currentFrozen = __frozenTokens[userAddress];
        uint256 availableBalance = __custodian_getBalance(userAddress) - currentFrozen;
        if (availableBalance < amount) {
            revert FreezeAmountExceedsAvailableBalance(availableBalance, amount);
        }
        __frozenTokens[userAddress] = currentFrozen + amount;
        emit TokensFrozen(_smartSender(), userAddress, amount);
    }

    /// @dev Internal function to freeze a partial amount of tokens for multiple addresses.
    /// @param userAddresses The addresses to freeze the tokens for.
    /// @param amounts The amounts of tokens to freeze.
    function _smart_batchFreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        internal
        virtual
    {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        uint256 length = userAddresses.length;
        for (uint256 i = 0; i < length;) {
            _smart_freezePartialTokens(userAddresses[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function to unfreeze a partial amount of tokens for an address.
    /// @param userAddress The address to unfreeze the tokens for.
    /// @param amount The amount of tokens to unfreeze.
    function _smart_unfreezePartialTokens(address userAddress, uint256 amount) internal virtual {
        uint256 currentFrozen = __frozenTokens[userAddress];
        if (currentFrozen < amount) {
            revert InsufficientFrozenTokens(currentFrozen, amount);
        }
        __frozenTokens[userAddress] = currentFrozen - amount;
        emit TokensUnfrozen(_smartSender(), userAddress, amount);
    }

    /// @dev Internal function to unfreeze a partial amount of tokens for multiple addresses.
    /// @param userAddresses The addresses to unfreeze the tokens for.
    /// @param amounts The amounts of tokens to unfreeze.
    function _smart_batchUnfreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        internal
        virtual
    {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        uint256 length = userAddresses.length;
        for (uint256 i = 0; i < length;) {
            _smart_unfreezePartialTokens(userAddresses[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function to force a transfer.
    /// @param from The sender address.
    /// @param to The recipient address.
    /// @param amount The amount to transfer.
    function _smart_forcedTransfer(address from, address to, uint256 amount) internal virtual returns (bool) {
        // Note: Core validation (frozen checks) should ideally happen *before* calling this,
        // potentially in overridden _beforeTransfer hooks, but forcedTransfer bypasses those.
        // Direct balance check is necessary here.
        uint256 currentBalance = __custodian_getBalance(from);
        if (currentBalance < amount) revert IERC20Errors.ERC20InsufficientBalance(from, currentBalance, amount);

        // Unfreeze tokens if needed
        uint256 currentFrozen = __frozenTokens[from];
        if (currentFrozen > 0) {
            uint256 freeBalance = currentBalance - currentFrozen;
            if (amount > freeBalance) {
                uint256 neededFromFrozen = amount - freeBalance;
                __frozenTokens[from] = currentFrozen - neededFromFrozen;
                emit TokensUnfrozen(_smartSender(), from, neededFromFrozen);
            }
        }

        // Execute transfer bypassing hooks
        __isForcedUpdate = true;
        __custodian_executeTransferUpdate(from, to, amount);
        __isForcedUpdate = false;

        return true;
    }

    /// @dev Internal function to force a transfer for multiple addresses.
    /// @param fromList The sender addresses.
    /// @param toList The recipient addresses.
    /// @param amounts The amounts to transfer.
    function _smart_batchForcedTransfer(
        address[] calldata fromList,
        address[] calldata toList,
        uint256[] calldata amounts
    )
        internal
        virtual
    {
        if (!((fromList.length == toList.length) && (toList.length == amounts.length))) {
            revert LengthMismatch();
        }
        uint256 length = fromList.length;
        for (uint256 i = 0; i < length;) {
            // Call internal logic directly for efficiency within the loop
            _smart_forcedTransfer(fromList[i], toList[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function to recover an address.
    /// @param lostWallet The lost wallet address.
    /// @param newWallet The new wallet address.
    /// @param investorOnchainID The investor onchain ID.
    function _smart_recoveryAddress(
        address lostWallet,
        address newWallet,
        address investorOnchainID
    )
        internal
        virtual
        returns (bool)
    {
        uint256 balance = __custodian_getBalance(lostWallet);
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
        __custodian_executeTransferUpdate(lostWallet, newWallet, balance);
        __isForcedUpdate = false;

        // Transfer frozen tokens state
        if (frozenTokens > 0) {
            emit TokensUnfrozen(_smartSender(), lostWallet, frozenTokens);
            __frozenTokens[lostWallet] = 0;
            __frozenTokens[newWallet] = frozenTokens;
            emit TokensFrozen(_smartSender(), newWallet, frozenTokens);
        }

        // Transfer frozen status state
        if (walletFrozen) {
            __frozen[newWallet] = true;
            __frozen[lostWallet] = false; // Ensure old wallet is unfrozen
            emit AddressFrozen(_smartSender(), newWallet, true);
            emit AddressFrozen(_smartSender(), lostWallet, false);
        } else if (__frozen[newWallet]) {
            // Defensive: Ensure new wallet isn't incorrectly marked frozen if old wasn't
            __frozen[newWallet] = false;
            emit AddressFrozen(_smartSender(), newWallet, false);
        }

        // Throw event before external calls to avoid reentrancy
        emit RecoverySuccess(_smartSender(), lostWallet, newWallet, investorOnchainID);

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

        return true;
    }

    // -- View Functions --

    /// @inheritdoc ISMARTCustodian
    function isFrozen(address userAddress) external view virtual override returns (bool) {
        return __frozen[userAddress];
    }

    /// @inheritdoc ISMARTCustodian
    function getFrozenTokens(address userAddress) external view virtual override returns (uint256) {
        return __frozenTokens[userAddress];
    }

    // -- Internal Hook Helper Functions --

    /// @notice Internal logic executed before a mint operation to check recipient freeze status.
    /// @dev Called by the implementing contract's `_beforeMint` hook.
    /// @param to The recipient address.
    //  Note: amount parameter is unused in this specific hook implementation.
    function __custodian_beforeMintLogic(address to, uint256 /* amount */ ) internal view virtual {
        if (__frozen[to]) revert RecipientAddressFrozen();
    }

    /// @notice Internal logic executed before a transfer to check sender/recipient freeze status and available balance.
    /// @dev Called by the implementing contract's `_beforeTransfer` hook.
    /// @param from The sender address.
    /// @param to The recipient address.
    /// @param amount The amount being transferred.
    function __custodian_beforeTransferLogic(address from, address to, uint256 amount) internal view virtual {
        if (!__isForcedUpdate) {
            if (__frozen[from]) revert SenderAddressFrozen();
            if (__frozen[to]) revert RecipientAddressFrozen();

            uint256 frozenTokens = __frozenTokens[from];
            // Check against available *unfrozen* balance
            uint256 availableUnfrozen = __custodian_getBalance(from) - frozenTokens;
            if (availableUnfrozen < amount) {
                // Revert using standard ERC20 error for insufficient balance (considering frozen amount)
                revert IERC20Errors.ERC20InsufficientBalance(from, availableUnfrozen, amount);
            }
        }
    }

    /// @notice Internal logic executed before a burn operation (typically admin-initiated).
    /// @dev Checks total balance and automatically unfreezes tokens if the burn amount exceeds the free balance.
    ///      Called by the implementing contract's `_beforeBurn` hook.
    /// @param from The address whose tokens are being burned.
    /// @param amount The amount being burned.
    function __custodian_beforeBurnLogic(address from, uint256 amount) internal virtual {
        // Note: Burn operation itself needs authorization (e.g., BURNER_ROLE) handled elsewhere.
        uint256 totalBalance = __custodian_getBalance(from);
        if (!__isForcedUpdate) {
            if (totalBalance < amount) {
                revert IERC20Errors.ERC20InsufficientBalance(from, totalBalance, amount);
            }
        }

        uint256 currentFrozen = __frozenTokens[from];
        if (currentFrozen > 0) {
            uint256 freeBalance = totalBalance - currentFrozen;
            if (amount > freeBalance) {
                // Amount requires dipping into frozen tokens, so unfreeze the difference.
                uint256 tokensToUnfreeze = amount - freeBalance;
                // The total balance check above ensures currentFrozen >= tokensToUnfreeze
                _smart_unfreezePartialTokens(from, tokensToUnfreeze); // Use internal logic directly
            }
        }
        // The actual _burn should occur after this hook in the inheriting contract.
    }

    /// @notice Internal logic executed before a redeem operation (typically user-initiated).
    /// @dev Checks sender freeze status and ensures enough *unfrozen* balance is available.
    ///      Called by the implementing contract's `_beforeRedeem` hook.
    /// @param from The address redeeming tokens.
    /// @param amount The amount being redeemed.
    function __custodian_beforeRedeemLogic(address from, uint256 amount) internal view virtual {
        if (__frozen[from]) revert SenderAddressFrozen();

        uint256 frozenTokens = __frozenTokens[from];
        uint256 availableUnfrozen = __custodian_getBalance(from) - frozenTokens;
        if (availableUnfrozen < amount) {
            revert IERC20Errors.ERC20InsufficientBalance(from, availableUnfrozen, amount);
        }
    }
}
