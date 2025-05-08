// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

import { Context } from "@openzeppelin/contracts/utils/Context.sol";

abstract contract SMARTContext {
    function _smartSender() internal view virtual returns (address);

    function _smartData() internal view virtual returns (bytes calldata);
}
