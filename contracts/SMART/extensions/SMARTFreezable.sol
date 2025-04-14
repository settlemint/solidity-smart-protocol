// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";

/// @title SMARTFreezable
/// @notice Extension that adds freezing functionality to SMART tokens
abstract contract SMARTFreezable is ISMART {
    mapping(address => bool) private _frozen;
    mapping(address => uint256) private _frozenTokens;

    /// @inheritdoc ISMARTFreezable
    function setAddressFrozen(address _userAddress, bool _freeze) public virtual override {
        _frozen[_userAddress] = _freeze;
        emit AddressFrozen(_userAddress, _freeze, msg.sender);
    }

    /// @inheritdoc ISMARTFreezable
    function freezePartialTokens(address _userAddress, uint256 _amount) public virtual override {
        require(balanceOf(_userAddress) >= _amount, "Insufficient balance");
        _frozenTokens[_userAddress] += _amount;
        emit TokensFrozen(_userAddress, _amount);
    }

    /// @inheritdoc ISMARTFreezable
    function unfreezePartialTokens(address _userAddress, uint256 _amount) public virtual override {
        require(_frozenTokens[_userAddress] >= _amount, "Insufficient frozen tokens");
        _frozenTokens[_userAddress] -= _amount;
        emit TokensUnfrozen(_userAddress, _amount);
    }

    /// @inheritdoc ISMARTFreezable
    function isFrozen(address _userAddress) public view virtual override returns (bool) {
        return _frozen[_userAddress];
    }

    /// @inheritdoc ISMARTFreezable
    function getFrozenTokens(address _userAddress) public view virtual override returns (uint256) {
        return _frozenTokens[_userAddress];
    }

    /// @inheritdoc ISMARTFreezable
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

    /// @inheritdoc ISMARTFreezable
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

    /// @inheritdoc ISMARTFreezable
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
}
