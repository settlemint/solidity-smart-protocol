// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMARTIdentityRegistry } from "../../interface/ISMARTIdentityRegistry.sol";
import { IIdentity } from "../../../onchainid/interface/IIdentity.sol";
import { LengthMismatch } from "../common/CommonErrors.sol";

/// @title _SMARTCustodianLogic
/// @notice Base logic contract for SMARTCustodian functionality.
abstract contract _SMARTCustodianLogic {
    // --- Storage Variables ---
    mapping(address => bool) internal __frozen;
    mapping(address => uint256) internal __frozenTokens;

    // --- Errors ---
    error FreezeAmountExceedsAvailableBalance(uint256 available, uint256 requested);
    error InsufficientFrozenTokens(uint256 frozenBalance, uint256 requested);
    error InsufficientTotalBalance(uint256 balance, uint256 requested);
    error InconsistentForcedTransferState();
    error NoTokensToRecover();
    error RecoveryWalletsNotVerified();
    error RecoveryTargetAddressFrozen();
    error RecipientAddressFrozen();
    error SenderAddressFrozen();
    error InsufficientUnfrozenTokens(uint256 available, uint256 requested);

    // --- Events ---
    event AddressFrozen(address indexed userAddress, bool indexed isFrozen);
    event RecoverySuccess(address indexed lostWallet, address indexed newWallet, address indexed investorOnchainID);
    event TokensFrozen(address indexed user, uint256 amount);
    event TokensUnfrozen(address indexed user, uint256 amount);

    // --- Abstract Functions ---

    /// @dev Returns the token balance of an address.
    function _getBalance(address account) internal view virtual returns (uint256);

    /// @dev Returns the identity registry instance.
    function _getIdentityRegistry() internal view virtual returns (ISMARTIdentityRegistry);

    /// @dev Returns the required claim topics.
    function _getRequiredClaimTopics() internal view virtual returns (uint256[] memory);

    /// @dev Executes the underlying token transfer (e.g., ERC20._update).
    function _executeTransferUpdate(address from, address to, uint256 amount) internal virtual;

    // --- View Functions ---

    function isFrozen(address userAddress) public view virtual returns (bool) {
        return __frozen[userAddress];
    }

    function getFrozenTokens(address userAddress) public view virtual returns (uint256) {
        return __frozenTokens[userAddress];
    }

    // --- Internal Functions ---

    function _setAddressFrozen(address userAddress, bool freeze) internal virtual {
        __frozen[userAddress] = freeze;
        emit AddressFrozen(userAddress, freeze);
    }

    function _freezePartialTokens(address userAddress, uint256 amount) internal virtual {
        uint256 currentFrozen = __frozenTokens[userAddress];
        // Use abstract getter for balance
        uint256 availableBalance = _getBalance(userAddress) - currentFrozen;
        if (availableBalance < amount) {
            revert FreezeAmountExceedsAvailableBalance(availableBalance, amount);
        }
        __frozenTokens[userAddress] = currentFrozen + amount;
        emit TokensFrozen(userAddress, amount);
    }

    function _unfreezePartialTokens(address userAddress, uint256 amount) internal virtual {
        uint256 currentFrozen = __frozenTokens[userAddress];
        if (currentFrozen < amount) {
            revert InsufficientFrozenTokens(currentFrozen, amount);
        }
        __frozenTokens[userAddress] = currentFrozen - amount;
        emit TokensUnfrozen(userAddress, amount);
    }

    function _forcedTransfer(address from, address to, uint256 amount) internal virtual {
        // Validation is expected to be called by the concrete contract's `_validateTransfer` override first.
        uint256 currentFrozen = __frozenTokens[from];
        uint256 currentBalance = _getBalance(from);
        uint256 freeBalance = currentBalance - currentFrozen;

        if (currentBalance < amount) revert InsufficientTotalBalance(currentBalance, amount);

        if (amount > freeBalance) {
            uint256 neededFromFrozen = amount - freeBalance;
            // This check should be implicitly covered by the balance require above, but added for clarity
            if (currentFrozen < neededFromFrozen) revert InconsistentForcedTransferState();

            __frozenTokens[from] = currentFrozen - neededFromFrozen;
            emit TokensUnfrozen(from, neededFromFrozen);
        }

        // Delegate the actual update to the concrete contract
        _executeTransferUpdate(from, to, amount);
        // Note: _afterTransfer hook is expected to be called by the concrete contract after this.
    }

    function _recoveryAddress(address lostWallet, address newWallet, address investorOnchainID) internal virtual {
        uint256 balance = _getBalance(lostWallet);
        if (balance == 0) revert NoTokensToRecover();

        // Use abstract getters for context-dependent state
        ISMARTIdentityRegistry registry = _getIdentityRegistry();
        uint256[] memory topics = _getRequiredClaimTopics();

        if (!(registry.isVerified(lostWallet, topics) || registry.isVerified(newWallet, topics))) {
            revert RecoveryWalletsNotVerified();
        }
        if (__frozen[newWallet]) revert RecoveryTargetAddressFrozen();

        uint256 frozenTokens = __frozenTokens[lostWallet];
        bool walletFrozen = __frozen[lostWallet];

        // Delegate the actual update to the concrete contract
        _executeTransferUpdate(lostWallet, newWallet, balance);

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
        } else {
            __frozen[newWallet] = false; // Ensure new wallet isn't incorrectly marked frozen
        }

        // Update identity registry
        uint16 country = registry.investorCountry(lostWallet);
        if (!registry.isVerified(newWallet, topics)) {
            registry.registerIdentity(newWallet, IIdentity(investorOnchainID), country);
        }
        if (registry.isVerified(lostWallet, topics)) {
            registry.deleteIdentity(lostWallet);
        }

        emit RecoverySuccess(lostWallet, newWallet, investorOnchainID);
    }

    // Helper Functions for Hooks
    function _custodian_validateMintLogic(address to, uint256 /* amount */ ) internal virtual {
        if (__frozen[to]) revert RecipientAddressFrozen();
    }

    function _custodian_validateTransferLogic(address from, address to, uint256 amount) internal virtual {
        if (__frozen[from]) revert SenderAddressFrozen();
        if (__frozen[to]) revert RecipientAddressFrozen();

        uint256 frozenTokens = __frozenTokens[from];
        uint256 availableUnfrozen = _getBalance(from) - frozenTokens;
        if (availableUnfrozen < amount) {
            revert InsufficientUnfrozenTokens(availableUnfrozen, amount);
        }
    }

    function _custodian_validateBurnLogic(address from, uint256 amount) internal virtual {
        if (__frozen[from]) revert SenderAddressFrozen();

        uint256 frozenTokens = __frozenTokens[from];
        uint256 availableUnfrozen = _getBalance(from) - frozenTokens;
        if (availableUnfrozen < amount) {
            revert InsufficientUnfrozenTokens(availableUnfrozen, amount);
        }
    }
}
