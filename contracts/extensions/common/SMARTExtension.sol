// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { _SMARTExtension } from "./_SMARTExtension.sol";
import { SMARTContext } from "./SMARTContext.sol";
/// @title SMARTExtension
/// @notice Abstract contract that defines the internal hooks for standard SMART tokens.
/// @dev Base for standard SMART extensions, inheriting ERC20.
///      These hooks should be called first in any override implementation.

abstract contract SMARTExtension is _SMARTExtension, ERC20 {
    function _smartSender() internal view virtual override(SMARTContext) returns (address) {
        return _msgSender();
    }

    function _smartData() internal view virtual override(SMARTContext) returns (bytes calldata) {
        return _msgData();
    }
}
