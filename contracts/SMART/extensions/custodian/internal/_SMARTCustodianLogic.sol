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

/// @title _SMARTCustodianLogic
/// @notice Base logic contract for SMARTCustodian functionality.
abstract contract _SMARTCustodianLogic is _SMARTExtension, _SMARTCustodianAuthorizationHooks {
    // --- Storage Variables ---
    mapping(address => bool) internal __frozen;
    mapping(address => uint256) internal __frozenTokens;

    // --- Errors ---
    error FreezeAmountExceedsAvailableBalance(uint256 available, uint256 requested);
    error InsufficientFrozenTokens(uint256 frozenBalance, uint256 requested);
    error InconsistentForcedTransferState();
    error NoTokensToRecover();
    error RecoveryWalletsNotVerified();
    error RecoveryTargetAddressFrozen();
    error RecipientAddressFrozen();
    error SenderAddressFrozen();

    // --- Events ---
    event AddressFrozen(address indexed userAddress, bool indexed isFrozen);
    event RecoverySuccess(address indexed lostWallet, address indexed newWallet, address indexed investorOnchainID);
    event TokensFrozen(address indexed user, uint256 amount);
    event TokensUnfrozen(address indexed user, uint256 amount);

    // --- Abstract Functions ---

    /// @dev Returns the token balance of an address using ERC20Upgradeable.balanceOf.
    function _getBalance(address account) internal view virtual returns (uint256);

    /// @dev Executes the underlying token transfer (e.g., ERC20._update).
    function _executeTransferUpdate(address from, address to, uint256 amount) internal virtual;

    // --- State-Changing Functions ---

    function setAddressFrozen(address userAddress, bool freeze) external virtual {
        _setAddressFrozen(userAddress, freeze); // Calls base logic
    }

    function freezePartialTokens(address userAddress, uint256 amount) external virtual {
        _freezePartialTokens(userAddress, amount); // Calls base logic
    }

    function unfreezePartialTokens(address userAddress, uint256 amount) external virtual {
        _unfreezePartialTokens(userAddress, amount); // Calls base logic
    }

    function batchSetAddressFrozen(address[] calldata userAddresses, bool[] calldata freeze) external virtual {
        if (userAddresses.length != freeze.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _setAddressFrozen(userAddresses[i], freeze[i]); // Calls base logic
        }
    }

    function batchFreezePartialTokens(address[] calldata userAddresses, uint256[] calldata amounts) external virtual {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _freezePartialTokens(userAddresses[i], amounts[i]); // Calls base logic
        }
    }

    function batchUnfreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        external
        virtual
    {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _unfreezePartialTokens(userAddresses[i], amounts[i]); // Calls base logic
        }
    }

    /// @dev Requires owner privileges.
    function forcedTransfer(address from, address to, uint256 amount) external virtual returns (bool) {
        _forcedTransfer(from, to, amount); // Call internal logic from base
        return true;
    }

    /// @dev Requires owner privileges.
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
        for (uint256 i = 0; i < fromList.length; i++) {
            _forcedTransfer(fromList[i], toList[i], amounts[i]); // Calls single forcedTransfer
        }
    }

    /// @dev Requires owner privileges.
    function recoveryAddress(
        address lostWallet,
        address newWallet,
        address investorOnchainID
    )
        external
        virtual
        returns (bool)
    {
        _recoveryAddress(lostWallet, newWallet, investorOnchainID); // Calls base logic
        return true;
    }

    // --- View Functions ---

    function isFrozen(address userAddress) external view virtual returns (bool) {
        return __frozen[userAddress];
    }

    function getFrozenTokens(address userAddress) external view virtual returns (uint256) {
        return __frozenTokens[userAddress];
    }

    // --- Internal Functions ---

    function _setAddressFrozen(address userAddress, bool freeze) internal virtual {
        _authorizeFreezeAddress();
        __frozen[userAddress] = freeze;
        emit AddressFrozen(userAddress, freeze);
    }

    function _freezePartialTokens(address userAddress, uint256 amount) internal virtual {
        _authorizeFreezePartialTokens();
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
        _authorizeFreezeAddress();
        uint256 currentFrozen = __frozenTokens[userAddress];
        if (currentFrozen < amount) {
            revert InsufficientFrozenTokens(currentFrozen, amount);
        }
        __frozenTokens[userAddress] = currentFrozen - amount;
        emit TokensUnfrozen(userAddress, amount);
    }

    function _forcedTransfer(address from, address to, uint256 amount) internal virtual {
        _authorizeForcedTransfer();

        // Validation is expected to be called by the concrete contract's `_beforeTransfer` override first.
        uint256 currentFrozen = __frozenTokens[from];
        uint256 currentBalance = _getBalance(from);
        uint256 freeBalance = currentBalance - currentFrozen;

        if (currentBalance < amount) revert IERC20Errors.ERC20InsufficientBalance(from, currentBalance, amount);

        if (amount > freeBalance) {
            uint256 neededFromFrozen = amount - freeBalance;
            // This check should be implicitly covered by the balance require above, but added for clarity
            if (currentFrozen < neededFromFrozen) revert InconsistentForcedTransferState();

            __frozenTokens[from] = currentFrozen - neededFromFrozen;
            emit TokensUnfrozen(from, neededFromFrozen);
        }

        // Delegate the actual update to the concrete contract
        __isForcedUpdate = true;
        _executeTransferUpdate(from, to, amount);
        __isForcedUpdate = false;
        // Note: _afterTransfer hook is expected to be called by the concrete contract after this.
    }

    function _recoveryAddress(address lostWallet, address newWallet, address investorOnchainID) internal virtual {
        _authorizeRecoveryAddress();
        uint256 balance = _getBalance(lostWallet);
        if (balance == 0) revert NoTokensToRecover();

        // Use abstract getters for context-dependent state
        ISMARTIdentityRegistry registry = this.identityRegistry();

        if (!(registry.contains(lostWallet) || registry.contains(newWallet))) {
            revert RecoveryWalletsNotVerified();
        }
        if (__frozen[newWallet]) revert RecoveryTargetAddressFrozen();

        uint256 frozenTokens = __frozenTokens[lostWallet];
        bool walletFrozen = __frozen[lostWallet];

        // Delegate the actual update to the concrete contract
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
        } else {
            __frozen[newWallet] = false; // Ensure new wallet isn't incorrectly marked frozen
        }

        // Update identity registry
        if (registry.contains(lostWallet)) {
            uint16 country = registry.investorCountry(lostWallet);
            if (!registry.contains(newWallet)) {
                registry.registerIdentity(newWallet, IIdentity(investorOnchainID), country);
            }
            if (registry.contains(lostWallet)) {
                registry.deleteIdentity(lostWallet);
            }
        }

        emit RecoverySuccess(lostWallet, newWallet, investorOnchainID);
    }

    // -- Internal Functions --

    // Helper Functions for Hooks
    function _custodian_beforeMintLogic(address to, uint256 /* amount */ ) internal virtual {
        if (__frozen[to]) revert RecipientAddressFrozen();
    }

    function _custodian_beforeTransferLogic(address from, address to, uint256 amount) internal virtual {
        if (__frozen[from]) revert SenderAddressFrozen();
        if (__frozen[to]) revert RecipientAddressFrozen();

        uint256 frozenTokens = __frozenTokens[from];
        uint256 availableUnfrozen = _getBalance(from) - frozenTokens;
        if (availableUnfrozen < amount) {
            revert IERC20Errors.ERC20InsufficientBalance(from, availableUnfrozen, amount);
        }
    }

    /// @dev Free tokens from frozen balance if needed, this will be called by an admin
    function _custodian_beforeBurnLogic(address from, uint256 amount) internal virtual {
        uint256 totalBalance = _getBalance(from);
        if (totalBalance < amount) {
            revert IERC20Errors.ERC20InsufficientBalance(from, totalBalance, amount);
        }

        uint256 currentFrozen = __frozenTokens[from];
        if (currentFrozen > 0) {
            // Only proceed if there are frozen tokens
            uint256 freeBalance = totalBalance - currentFrozen;
            if (amount > freeBalance) {
                uint256 tokensToUnfreeze = amount - freeBalance;
                // The InsufficientTotalBalance check above ensures currentFrozen >= tokensToUnfreeze
                __frozenTokens[from] = currentFrozen - tokensToUnfreeze;
                emit TokensUnfrozen(from, tokensToUnfreeze);
            }
        }
        // Note: The actual _burn operation should happen in the calling contract after this validation.
    }

    /// @dev Block if there are not enough free tokens, else they will be unfrozen by validateBurnLogic
    function _custodian_beforeRedeemLogic(address from, uint256 amount) internal virtual {
        if (__frozen[from]) revert SenderAddressFrozen();

        uint256 frozenTokens = __frozenTokens[from];
        uint256 availableUnfrozen = _getBalance(from) - frozenTokens;
        if (availableUnfrozen < amount) {
            revert IERC20Errors.ERC20InsufficientBalance(from, availableUnfrozen, amount);
        }
    }
}
