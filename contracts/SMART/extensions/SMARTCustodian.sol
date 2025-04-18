// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";
import { SMARTExtension } from "./SMARTExtension.sol";
import { ISMARTIdentityRegistry } from "./../interface/ISMARTIdentityRegistry.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // Still needed for override specifiers
import { IIdentity } from "../../onchainid/interface/IIdentity.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LengthMismatch } from "./common/CommonErrors.sol";

/// @title SMARTCustodian
/// @notice Extension that adds custodian features like freezing, forced transfer, and recovery to SMART tokens.
/// @dev This contract implements functionality similar to aspects of ERC3643 standard.
/// It allows for address-level freezing, partial token freezing, forced transfers, and wallet recovery.
/// @dev This contract intentionally does NOT inherit from OpenZeppelin Community's ERC20Custodian.
///      The reason is that ERC20Custodian implements a different freezing mechanism (setting a total frozen amount)
///      whereas this contract requires both a boolean address-level freeze and an additive/subtractive partial freeze
/// amount.
///      Leveraging ERC20Custodian's state and logic would be overly complex and less efficient for these requirements.
abstract contract SMARTCustodian is SMARTExtension, Ownable {
    // --- Storage Variables ---

    mapping(address => bool) private _frozen;
    mapping(address => uint256) private _frozenTokens;

    // --- Errors ---

    /// @dev Error triggered when attempting to freeze more tokens than are available (balance - already frozen).
    /// @param available The available, non-frozen balance.
    /// @param requested The amount requested to be frozen.
    error FreezeAmountExceedsAvailableBalance(uint256 available, uint256 requested);
    /// @dev Error triggered when attempting to unfreeze more tokens than are currently frozen.
    /// @param frozenBalance The currently frozen balance.
    /// @param requested The amount requested to be unfrozen.
    error InsufficientFrozenTokens(uint256 frozenBalance, uint256 requested);
    /// @dev Error triggered during forced transfer if the sender does not have enough total balance.
    /// @param balance The total balance of the sender.
    /// @param requested The amount requested to be transferred.
    error InsufficientTotalBalance(uint256 balance, uint256 requested);
    /// @dev Error triggered during forced transfer if an inconsistent state is detected (should not happen).
    error InconsistentForcedTransferState();
    /// @dev Error triggered when attempting recovery on a wallet with zero balance.
    error NoTokensToRecover();
    /// @dev Error triggered during recovery if neither the lost nor the new wallet is verified for required topics.
    error RecoveryWalletsNotVerified();
    /// @dev Error triggered when attempting recovery to a new wallet that is currently frozen.
    error RecoveryTargetAddressFrozen();
    /// @dev Error triggered when attempting an operation where the recipient address is frozen.
    error RecipientAddressFrozen(); // Used in _validateMint
    /// @dev Error triggered when attempting an operation where the sender address is frozen.
    error SenderAddressFrozen(); // Used in _validateTransfer, _validateBurn
    /// @dev Error triggered when attempting a transfer or burn without sufficient unfrozen tokens.
    /// @param available The available unfrozen balance.
    /// @param requested The amount requested for the operation.
    error InsufficientUnfrozenTokens(uint256 available, uint256 requested);

    // --- Events ---

    /// @dev This event is emitted when the wallet of an investor is frozen or unfrozen.
    /// @param _userAddress is the wallet of the investor that is concerned by the freezing status.
    /// @param _isFrozen is the freezing status of the wallet.
    event AddressFrozen(address indexed _userAddress, bool indexed _isFrozen);

    /// @dev Emitted when a wallet recovery is successful
    event RecoverySuccess(address indexed _lostWallet, address indexed _newWallet, address indexed _investorOnchainID);

    /// @dev Emitted when tokens are partially frozen for a user via freezePartialTokens.
    /// @param user The address of the user whose tokens were frozen.
    /// @param amount The amount of tokens that were frozen in this operation.
    event TokensFrozen(address indexed user, uint256 amount);

    /// @dev Emitted when tokens are partially unfrozen for a user via unfreezePartialTokens or forcedTransfer.
    /// @param user The address of the user whose tokens were unfrozen.
    /// @param amount The amount of tokens that were unfrozen in this operation.
    event TokensUnfrozen(address indexed user, uint256 amount);

    // --- Constructor ---

    // No constructor needed currently.

    // --- State-Changing Functions ---

    /// @dev Sets an address's frozen status for this token.
    /// @param _userAddress The address for which to update the frozen status.
    /// @param _freeze The frozen status to be applied: `true` to freeze, `false` to unfreeze.
    function setAddressFrozen(address _userAddress, bool _freeze) public virtual onlyOwner {
        _frozen[_userAddress] = _freeze;
        emit AddressFrozen(_userAddress, _freeze);
    }

    /// @dev Freezes a specified token amount for a given address.
    /// @param _userAddress The address for which to freeze tokens.
    /// @param _amount The amount of tokens to be frozen.
    function freezePartialTokens(address _userAddress, uint256 _amount) public virtual onlyOwner {
        uint256 currentFrozen = _frozenTokens[_userAddress];
        uint256 availableBalance = balanceOf(_userAddress) - currentFrozen;
        if (availableBalance < _amount) {
            revert FreezeAmountExceedsAvailableBalance(availableBalance, _amount);
        }
        _frozenTokens[_userAddress] = currentFrozen + _amount;
        emit TokensFrozen(_userAddress, _amount); // Emit locally defined event
    }

    /// @dev Unfreezes a specified token amount for a given address.
    /// @param _userAddress The address for which to unfreeze tokens.
    /// @param _amount The amount of tokens to be unfrozen.
    function unfreezePartialTokens(address _userAddress, uint256 _amount) public virtual onlyOwner {
        uint256 currentFrozen = _frozenTokens[_userAddress];
        if (currentFrozen < _amount) {
            revert InsufficientFrozenTokens(currentFrozen, _amount);
        }
        _frozenTokens[_userAddress] = currentFrozen - _amount;
        emit TokensUnfrozen(_userAddress, _amount); // Emit locally defined event
    }

    /// @dev Initiates setting of frozen status for addresses in batch.
    /// @param _userAddresses The addresses for which to update frozen status.
    /// @param _freeze Frozen status of the corresponding address.
    function batchSetAddressFrozen(
        address[] calldata _userAddresses,
        bool[] calldata _freeze
    )
        public
        virtual
        onlyOwner
    {
        if (_userAddresses.length != _freeze.length) revert LengthMismatch();
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            setAddressFrozen(_userAddresses[i], _freeze[i]);
        }
    }

    /// @dev Initiates partial freezing of tokens in batch.
    /// @param _userAddresses The addresses on which tokens need to be partially frozen.
    /// @param _amounts The amount of tokens to freeze on the corresponding address.
    function batchFreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    )
        public
        virtual
        onlyOwner
    {
        if (_userAddresses.length != _amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            freezePartialTokens(_userAddresses[i], _amounts[i]);
        }
    }

    /// @dev Initiates partial unfreezing of tokens in batch.
    /// @param _userAddresses The addresses on which tokens need to be partially unfrozen.
    /// @param _amounts The amount of tokens to unfreeze on the corresponding address.
    function batchUnfreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    )
        public
        virtual
        onlyOwner
    {
        if (_userAddresses.length != _amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            unfreezePartialTokens(_userAddresses[i], _amounts[i]);
        }
    }

    /// @dev Initiates a forced transfer of tokens between two wallets, bypassing some standard checks.
    /// If the `from` address does not have sufficient free tokens (unfrozen tokens)
    /// but possesses a total balance equal to or greater than the specified `amount`,
    /// the frozen token amount is reduced only by the amount needed to cover the transfer.
    /// It is imperative that the `to` address is a verified and whitelisted address.
    /// @param _from The address of the sender.
    /// @param _to The address of the receiver.
    /// @param _amount The number of tokens to be transferred.
    /// @return bool `true` if the transfer was successful.
    /// @notice Emits a `TokensUnfrozen` event if frozen tokens need to be used for the transfer.
    /// Also emits a `Transfer` event.
    function forcedTransfer(address _from, address _to, uint256 _amount) public virtual onlyOwner returns (bool) {
        _validateTransfer(_from, _to, _amount); // Initial validation (checks frozen status, basic rules)

        uint256 currentFrozen = _frozenTokens[_from];
        uint256 currentBalance = balanceOf(_from);
        uint256 freeBalance = currentBalance - currentFrozen;

        if (currentBalance < _amount) revert InsufficientTotalBalance(currentBalance, _amount);

        if (_amount > freeBalance) {
            uint256 neededFromFrozen = _amount - freeBalance;
            // This check should be implicitly covered by the balance require above
            if (currentFrozen < neededFromFrozen) revert InconsistentForcedTransferState();

            _frozenTokens[_from] = currentFrozen - neededFromFrozen;
            emit TokensUnfrozen(_from, neededFromFrozen); // Emit locally defined event
        }

        // We bypass the standard _transfer's internal checks as we've already handled frozen logic
        // We directly call the parent's _update which calls ERC20 _update
        super._update(_from, _to, _amount); // Use super._update to bypass local _transfer override
        _afterTransfer(_from, _to, _amount); // Call hooks if necessary

        return true;
    }

    /// @dev Initiates forced transfers in batch.
    /// @param _fromList The addresses of the senders.
    /// @param _toList The addresses of the receivers.
    /// @param _amounts The number of tokens to transfer to the corresponding receiver.
    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    )
        public
        virtual
        onlyOwner
    {
        if (!(_fromList.length == _toList.length && _toList.length == _amounts.length)) {
            revert LengthMismatch();
        }
        for (uint256 i = 0; i < _fromList.length; i++) {
            forcedTransfer(_fromList[i], _toList[i], _amounts[i]); // forcedTransfer now handles partial unfreeze
        }
    }

    /// @dev Recovers tokens and state from a lost wallet to a new one.
    /// @param _lostWallet The wallet address the user lost access to.
    /// @param _newWallet The new wallet address for the user.
    /// @param _investorOnchainID The OnchainID address of the investor.
    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    )
        public
        virtual
        onlyOwner
        returns (bool)
    {
        if (balanceOf(_lostWallet) == 0) revert NoTokensToRecover();

        ISMARTIdentityRegistry registry = this.identityRegistry(); // Cache the registry
        uint256[] memory topics = this.requiredClaimTopics(); // Cache the topics
        if (!(registry.isVerified(_lostWallet, topics) || registry.isVerified(_newWallet, topics))) {
            revert RecoveryWalletsNotVerified();
        }
        if (_frozen[_newWallet]) revert RecoveryTargetAddressFrozen();

        uint256 balance = balanceOf(_lostWallet);
        uint256 frozenTokens = _frozenTokens[_lostWallet]; // Use internal state directly
        bool walletFrozen = _frozen[_lostWallet]; // Use internal state directly

        // Get the country from the old wallet if needed by registry logic
        uint16 country = registry.investorCountry(_lostWallet); // Cache country

        // Directly update balances and state, bypassing standard transfer hooks/checks
        // as this is a special recovery operation.
        super._update(_lostWallet, address(0), balance); // Burn from old wallet (semantically)
        super._update(address(0), _newWallet, balance); // Mint to new wallet (semantically)

        // Transfer frozen tokens state
        if (frozenTokens > 0) {
            emit TokensUnfrozen(_lostWallet, frozenTokens); // Emit locally defined event
            _frozenTokens[_lostWallet] = 0;
            _frozenTokens[_newWallet] = frozenTokens; // Assign frozen amount to new wallet
            emit TokensFrozen(_newWallet, frozenTokens); // Emit locally defined event
        }

        // Transfer frozen status state
        if (walletFrozen) {
            _frozen[_newWallet] = true; // Assign frozen status to new wallet
            _frozen[_lostWallet] = false; // Ensure old wallet is unfrozen
            emit AddressFrozen(_newWallet, true);
            emit AddressFrozen(_lostWallet, false);
        } else {
            // Ensure new wallet isn't incorrectly marked frozen if old wasn't
            _frozen[_newWallet] = false;
        }

        // Update identity registry if the new wallet isn't already verified
        // This check prevents unnecessary registry writes if the user already setup the new wallet
        if (!registry.isVerified(_newWallet, topics)) {
            // Use cached topics
            registry.registerIdentity(_newWallet, IIdentity(_investorOnchainID), country);
        }
        // Always attempt deletion from the old wallet if it was verified
        if (registry.isVerified(_lostWallet, topics)) {
            registry.deleteIdentity(_lostWallet);
        }

        emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainID);
        return true;
    }

    // --- View Functions ---

    /// @dev Returns the freezing status of a wallet.
    /// @param _userAddress The address of the wallet to check.
    /// @return bool `true` if the wallet is frozen, `false` otherwise.
    /// @notice A return value of `true` doesn't mean that the balance is free, tokens could be blocked by
    /// a partial freeze or the whole token could be blocked by pause.
    function isFrozen(address _userAddress) public view virtual returns (bool) {
        return _frozen[_userAddress];
    }

    /// @dev Returns the amount of tokens that are partially frozen on a wallet.
    /// @param _userAddress The address of the wallet to check.
    /// @return uint256 The amount of frozen tokens.
    /// @notice The amount of frozen tokens is always <= to the total balance of the wallet.
    function getFrozenTokens(address _userAddress) public view virtual returns (uint256) {
        return _frozenTokens[_userAddress];
    }

    // --- Internal Functions ---

    /// @notice Override validation hooks to include freezing checks
    function _validateMint(address _to, uint256 _amount) internal virtual override {
        if (_frozen[_to]) revert RecipientAddressFrozen();
        super._validateMint(_to, _amount);
    }

    function _validateTransfer(address _from, address _to, uint256 _amount) internal virtual override {
        if (_frozen[_from]) revert SenderAddressFrozen();
        if (_frozen[_to]) revert RecipientAddressFrozen();

        // Check if sender has enough unfrozen tokens
        uint256 frozenTokens = _frozenTokens[_from];
        uint256 availableUnfrozen = balanceOf(_from) - frozenTokens;
        if (availableUnfrozen < _amount) {
            revert InsufficientUnfrozenTokens(availableUnfrozen, _amount);
        }

        super._validateTransfer(_from, _to, _amount);
    }

    function _validateBurn(address _from, uint256 _amount) internal virtual override {
        if (_frozen[_from]) revert SenderAddressFrozen();

        // Check if sender has enough unfrozen tokens
        uint256 frozenTokens = _frozenTokens[_from];
        uint256 availableUnfrozen = balanceOf(_from) - frozenTokens;
        if (availableUnfrozen < _amount) {
            revert InsufficientUnfrozenTokens(availableUnfrozen, _amount);
        }

        super._validateBurn(_from, _amount);
    }
}
