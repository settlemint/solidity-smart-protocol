// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../../interface/ISMART.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

abstract contract _SMARTExtension is ISMART, SMARTHooks { }
