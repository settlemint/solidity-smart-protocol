// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "./ISMART.sol";

/// @title ISMARTFrozen
/// @notice Interface for SMART tokens with frozen functionality
interface ISMARTFrozen is ISMART {
    /// Events
    event TokensFrozen(address indexed account, uint256 amount);
    event TokensUnfrozen(address indexed account, uint256 amount);

    /// Functions
    function freeze(address _userAddress, uint256 _amount) external;
    function unfreeze(address _userAddress, uint256 _amount) external;
    function isFrozen(address _userAddress) external view returns (bool);
    function getFrozenTokens(address _userAddress) external view returns (uint256);
}
