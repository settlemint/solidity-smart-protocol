// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { ISMART } from "../../interface/ISMART.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";
import { SMARTContext } from "../common/SMARTContext.sol";
/// @title _SMARTExtension
/// @notice Base contract for SMART extension contracts.

abstract contract _SMARTExtension is ISMART, SMARTContext, SMARTHooks {
    bool internal __isForcedUpdate = false;
}
