// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "./ISMART.sol";

/// @title ISMARTRecovery
/// @notice Interface for SMART tokens with recovery functionality
interface ISMARTRecovery is ISMART {
    /// Events
    event RecoverySuccess(address indexed _lostWallet, address indexed _newWallet, address indexed _investorOnchainID);

    /// Functions
    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    )
        external
        returns (bool);
}
