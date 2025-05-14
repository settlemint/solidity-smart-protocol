// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

// Base contract imports
import { SMARTExtension } from "./../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTYieldLogic } from "./internal/_SMARTYieldLogic.sol";

/// @title Standard SMART Yield Extension
/// @notice Standard (non-upgradeable) extension allowing token holders to set the yield schedule.
/// @dev Inherits core yield management logic from `_SMARTYieldLogic`, `SMARTExtension`, and `Context`.
abstract contract SMARTYield is Context, SMARTExtension, _SMARTYieldLogic {
    constructor() {
        __SMARTYield_init_unchained();
    }

    // -- Hooks (Overrides) --

    /// @inheritdoc SMARTHooks
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        __yield_beforeMintLogic();
        super._beforeMint(to, amount); // Call next hook in the chain
    }
}
