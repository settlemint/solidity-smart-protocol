// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Interface imports
import { ISMART } from "./../../interface/ISMART.sol";

// Base contract imports
import { _SMARTExtension } from "./_SMARTExtension.sol";

/// @title SMARTExtension
/// @notice Abstract contract that defines the internal hooks for standard SMART tokens.
/// @dev Base for standard SMART extensions, inheriting ERC20.
///      These hooks should be called first in any override implementation.
abstract contract SMARTExtension is _SMARTExtension, ERC20 { }
