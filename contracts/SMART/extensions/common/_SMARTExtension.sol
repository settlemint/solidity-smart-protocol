// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../../interface/ISMART.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
/// @title _SMARTExtension
/// @notice Base contract for SMART extension contracts.

abstract contract _SMARTExtension is ISMART, SMARTHooks {
    bool internal __isForcedTransfer = false;
}
