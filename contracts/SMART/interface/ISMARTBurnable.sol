// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Burnable.sol";
import { ISMART } from "./ISMART.sol";

/// @title ISMARTBurnable
/// @notice Interface for SMART tokens with burnable functionality
interface ISMARTBurnable is ISMART, IERC20Burnable {
    /// Functions
    function burn(address _userAddress, uint256 _amount) external;
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) external;
}
