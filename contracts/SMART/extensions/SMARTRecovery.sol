// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";

/// @title SMARTRecovery
/// @notice Extension that adds recovery functionality to SMART tokens
abstract contract SMARTRecovery is ISMART {
    /// @inheritdoc ISMARTRecovery
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
        bool isFrozen = isFrozen(_lostWallet);

        // Transfer tokens
        _transfer(_lostWallet, _newWallet, balance);

        // Transfer frozen tokens
        if (frozenTokens > 0) {
            _frozenTokens[_newWallet] = frozenTokens;
            _frozenTokens[_lostWallet] = 0;
        }

        // Transfer frozen status
        if (isFrozen) {
            _frozen[_newWallet] = true;
            _frozen[_lostWallet] = false;
        }

        // Update identity registry
        if (identityRegistry().isVerified(_lostWallet)) {
            identityRegistry().unregisterIdentity(_lostWallet);
            if (!identityRegistry().isVerified(_newWallet)) {
                identityRegistry().registerIdentity(_newWallet, _investorOnchainID);
            }
        }

        emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainID);
        return true;
    }
}
