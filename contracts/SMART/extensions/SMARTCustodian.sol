// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";
import { SMARTHooks } from "./SMARTHooks.sol";
import { ISMARTIdentityRegistry } from "./../interface/ISmartIdentityRegistry.sol";
import { ERC20Custodian } from "@openzeppelin-community/contracts/token/ERC20/extensions/ERC20Custodian.sol";
import { IIdentity } from "../../onchainid/interface/IIdentity.sol";

/// @title SMARTFreezable
/// @notice Extension that adds freezing functionality to SMART tokens
/// @dev This contract implements the freezing functionality as defined in the ERC3643 standard.
/// It allows for both address-level freezing and partial token freezing.
abstract contract SMARTCustodian is ERC20Custodian, SMARTHooks, ISMART {
    /// @dev This event is emitted when the wallet of an investor is frozen or unfrozen.
    /// @param _userAddress is the wallet of the investor that is concerned by the freezing status.
    /// @param _isFrozen is the freezing status of the wallet.
    /// @param _isFrozen equals `true` the wallet is frozen after emission of the event.
    /// @param _isFrozen equals `false` the wallet is unfrozen after emission of the event.
    /// @param _owner is the address of the agent who called the function to freeze the wallet.
    event AddressFrozen(address indexed _userAddress, bool indexed _isFrozen, address indexed _owner);

    /// @dev This event is emitted when a certain amount of tokens is frozen on a wallet.
    /// @param _userAddress is the wallet of the investor that is concerned by the freezing status.
    /// @param _amount is the amount of tokens that are frozen.
    event TokensFrozen(address indexed _userAddress, uint256 _amount);

    /// @dev This event is emitted when a certain amount of tokens is unfrozen on a wallet.
    /// @param _userAddress is the wallet of the investor that is concerned by the freezing status.
    /// @param _amount is the amount of tokens that are unfrozen.
    event TokensUnfrozen(address indexed _userAddress, uint256 _amount);

    /// @dev Emitted when a wallet recovery is successful
    event RecoverySuccess(address indexed _lostWallet, address indexed _newWallet, address indexed _investorOnchainID);

    mapping(address => bool) private _frozen;
    mapping(address => uint256) private _frozenTokens;

    /// @dev Sets an address's frozen status for this token,
    /// either freezing or unfreezing the address based on the provided boolean value.
    /// This function can be called by an agent of the token, assuming the agent is not restricted from freezing
    /// addresses.
    /// @param _userAddress The address for which to update the frozen status.
    /// @param _freeze The frozen status to be applied: `true` to freeze, `false` to unfreeze.
    /// @notice To change an address's frozen status, the calling agent must have the capability to freeze addresses
    /// enabled.
    /// If the agent is disabled from freezing addresses, the function call will fail.
    function setAddressFrozen(address _userAddress, bool _freeze) public virtual override {
        _frozen[_userAddress] = _freeze;
        emit AddressFrozen(_userAddress, _freeze, msg.sender);
    }

    /// @dev Freezes a specified token amount for a given address, preventing those tokens from being transferred.
    /// This function can be called by an agent of the token, provided the agent is not restricted from freezing tokens.
    /// @param _userAddress The address for which to freeze tokens.
    /// @param _amount The amount of tokens to be frozen.
    /// @notice To freeze tokens for an address, the calling agent must have the capability to freeze tokens enabled.
    /// If the agent is disabled from freezing tokens, the function call will fail.
    /// @notice The function will revert if the user's balance is less than the amount to be frozen.
    function freezePartialTokens(address _userAddress, uint256 _amount) public virtual override {
        require(balanceOf(_userAddress) >= _amount, "Insufficient balance");
        _frozenTokens[_userAddress] += _amount;
        emit TokensFrozen(_userAddress, _amount);
    }

    /// @dev Unfreezes a specified token amount for a given address, allowing those tokens to be transferred again.
    /// This function can be called by an agent of the token, assuming the agent is not restricted from unfreezing
    /// tokens.
    /// @param _userAddress The address for which to unfreeze tokens.
    /// @param _amount The amount of tokens to be unfrozen.
    /// @notice To unfreeze tokens for an address, the calling agent must have the capability to unfreeze tokens
    /// enabled.
    /// If the agent is disabled from unfreezing tokens, the function call will fail.
    /// @notice The function will revert if the user has insufficient frozen tokens.
    function unfreezePartialTokens(address _userAddress, uint256 _amount) public virtual override {
        require(_frozenTokens[_userAddress] >= _amount, "Insufficient frozen tokens");
        _frozenTokens[_userAddress] -= _amount;
        emit TokensUnfrozen(_userAddress, _amount);
    }

    /// @dev Returns the freezing status of a wallet.
    /// @param _userAddress The address of the wallet to check.
    /// @return bool `true` if the wallet is frozen, `false` otherwise.
    /// @notice A return value of `true` doesn't mean that the balance is free, tokens could be blocked by
    /// a partial freeze or the whole token could be blocked by pause.
    function isFrozen(address _userAddress) public view virtual override returns (bool) {
        return _frozen[_userAddress];
    }

    /// @dev Returns the amount of tokens that are partially frozen on a wallet.
    /// @param _userAddress The address of the wallet to check.
    /// @return uint256 The amount of frozen tokens.
    /// @notice The amount of frozen tokens is always <= to the total balance of the wallet.
    function getFrozenTokens(address _userAddress) public view virtual override returns (uint256) {
        return _frozenTokens[_userAddress];
    }

    /// @dev Initiates setting of frozen status for addresses in batch.
    /// @param _userAddresses The addresses for which to update frozen status.
    /// @param _freeze Frozen status of the corresponding address.
    /// @notice IMPORTANT: THIS TRANSACTION COULD EXCEED GAS LIMIT IF `_userAddresses.length` IS TOO HIGH.
    /// USE WITH CARE TO AVOID "OUT OF GAS" TRANSACTIONS AND POTENTIAL LOSS OF TX FEES.
    function batchSetAddressFrozen(
        address[] calldata _userAddresses,
        bool[] calldata _freeze
    )
        public
        virtual
        override
    {
        require(_userAddresses.length == _freeze.length, "Length mismatch");
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            setAddressFrozen(_userAddresses[i], _freeze[i]);
        }
    }

    /// @dev Initiates partial freezing of tokens in batch.
    /// @param _userAddresses The addresses on which tokens need to be partially frozen.
    /// @param _amounts The amount of tokens to freeze on the corresponding address.
    /// @notice IMPORTANT: THIS TRANSACTION COULD EXCEED GAS LIMIT IF `_userAddresses.length` IS TOO HIGH.
    /// USE WITH CARE TO AVOID "OUT OF GAS" TRANSACTIONS AND POTENTIAL LOSS OF TX FEES.
    function batchFreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    )
        public
        virtual
        override
    {
        require(_userAddresses.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            freezePartialTokens(_userAddresses[i], _amounts[i]);
        }
    }

    /// @dev Initiates partial unfreezing of tokens in batch.
    /// @param _userAddresses The addresses on which tokens need to be partially unfrozen.
    /// @param _amounts The amount of tokens to unfreeze on the corresponding address.
    /// @notice IMPORTANT: THIS TRANSACTION COULD EXCEED GAS LIMIT IF `_userAddresses.length` IS TOO HIGH.
    /// USE WITH CARE TO AVOID "OUT OF GAS" TRANSACTIONS AND POTENTIAL LOSS OF TX FEES.
    function batchUnfreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    )
        public
        virtual
        override
    {
        require(_userAddresses.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            unfreezePartialTokens(_userAddresses[i], _amounts[i]);
        }
    }

    /// @dev Initiates a forced transfer of tokens between two whitelisted wallets.
    /// If the `from` address does not have sufficient free tokens (unfrozen tokens)
    /// but possesses a total balance equal to or greater than the specified `amount`,
    /// the frozen token amount is reduced to ensure enough free tokens for the transfer.
    /// In such cases, the remaining balance in the `from` account consists entirely of frozen tokens post-transfer.
    /// It is imperative that the `to` address is a verified and whitelisted address.
    /// @param _from The address of the sender.
    /// @param _to The address of the receiver.
    /// @param _amount The number of tokens to be transferred.
    /// @return bool `true` if the transfer was successful.
    /// @notice This function can only be invoked by a wallet designated as an agent of the token,
    /// provided the agent is not restricted from initiating forced transfers of the token.
    /// @notice Emits a `TokensUnfrozen` event if `_amount` is higher than the free balance of `_from`.
    /// Also emits a `Transfer` event.
    /// @notice The function can only be called when the contract is not already paused.
    function forcedTransfer(address _from, address _to, uint256 _amount) public virtual override returns (bool) {
        require(!_frozen[_to], "Recipient address is frozen");

        uint256 frozenTokens = _frozenTokens[_from];
        if (frozenTokens > 0) {
            _frozenTokens[_from] = 0;
            emit TokensUnfrozen(_from, frozenTokens);
        }

        _validateTransfer(_from, _to, _amount);
        _transfer(_from, _to, _amount);
        _afterTransfer(_from, _to, _amount);

        return true;
    }

    /// @dev Initiates forced transfers in batch.
    /// Requires that each _amounts[i] does not exceed the available balance of _fromList[i].
    /// Requires that the _toList addresses are all verified and whitelisted addresses.
    /// @param _fromList The addresses of the senders.
    /// @param _toList The addresses of the receivers.
    /// @param _amounts The number of tokens to transfer to the corresponding receiver.
    /// @notice IMPORTANT: THIS TRANSACTION COULD EXCEED GAS LIMIT IF _fromList.length IS TOO HIGH.
    /// USE WITH CARE TO AVOID "OUT OF GAS" TRANSACTIONS AND POTENTIAL LOSS OF TX FEES.
    /// @notice This function can only be called by a wallet designated as an agent of the token,
    /// provided the agent is not restricted from initiating forced transfers in batch.
    /// @notice Emits `TokensUnfrozen` events for each `_amounts[i]` that exceeds the free balance of `_fromList[i]`.
    /// Also emits _fromList.length `Transfer` events upon successful batch transfer.
    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    )
        public
        virtual
        override
    {
        require(_fromList.length == _toList.length && _toList.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _fromList.length; i++) {
            forcedTransfer(_fromList[i], _toList[i], _amounts[i]);
        }
    }

    function identityRegistry() public view virtual override returns (ISMARTIdentityRegistry);
    function requiredClaimTopics() public view virtual override returns (uint256[] memory);

    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    )
        public
        virtual
        override
        returns (bool)
    {
        require(balanceOf(_lostWallet) > 0, "No tokens to recover");
        require(
            identityRegistry().isVerified(_lostWallet) || identityRegistry().isVerified(_newWallet),
            "Neither wallet is verified"
        );

        uint256 balance = balanceOf(_lostWallet);
        uint256 frozenTokens = getFrozenTokens(_lostWallet);
        bool walletFrozen = isFrozen(_lostWallet);

        // Get the country from the old wallet
        uint16 country = identityRegistry().investorCountry(_lostWallet);

        // Transfer tokens
        _transfer(_lostWallet, _newWallet, balance);

        // Transfer frozen tokens
        if (frozenTokens > 0) {
            _frozenTokens[_newWallet] = frozenTokens;
            _frozenTokens[_lostWallet] = 0;
        }

        // Transfer frozen status
        if (walletFrozen) {
            _frozen[_newWallet] = true;
            _frozen[_lostWallet] = false;
        }

        // Update identity registry
        if (!identityRegistry().isVerified(_newWallet, requiredClaimTopics())) {
            identityRegistry().registerIdentity(_newWallet, IIdentity(_investorOnchainID), country);
            identityRegistry().deleteIdentity(_lostWallet);
        }

        emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainID);
        return true;
    }

    /// @notice Override validation hooks to include freezing checks
    function _validateMint(address _to, uint256 _amount) internal virtual override {
        require(!_frozen[_to], "Recipient address is frozen");
        super._validateMint(_to, _amount);
    }

    function _validateTransfer(address _from, address _to, uint256 _amount) internal virtual override {
        require(!_frozen[_from], "Sender address is frozen");
        require(!_frozen[_to], "Recipient address is frozen");

        // Check if sender has enough unfrozen tokens
        uint256 frozenTokens = _frozenTokens[_from];
        require(balanceOf(_from) - frozenTokens >= _amount, "Insufficient unfrozen tokens");

        super._validateTransfer(_from, _to, _amount);
    }

    /// @notice Override transfer functions to handle frozen tokens
    function _transfer(address _from, address _to, uint256 _amount) internal virtual override {
        require(!_frozen[_from], "Sender address is frozen");
        require(!_frozen[_to], "Recipient address is frozen");

        // Check if sender has enough unfrozen tokens
        uint256 frozenTokens = _frozenTokens[_from];
        require(balanceOf(_from) - frozenTokens >= _amount, "Insufficient unfrozen tokens");

        super._transfer(_from, _to, _amount);
    }
}
