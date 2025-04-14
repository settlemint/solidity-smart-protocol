// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Pausable.sol";
import { ISMART } from "./ISMART.sol";

/// @title ISMARTPausable
/// @notice Interface for SMART tokens with pausable functionality
interface ISMARTPausable is ISMART, IERC20Pausable {
    /// Events
    event Paused(address indexed account);
    event Unpaused(address indexed account);

    /// Functions
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
}
