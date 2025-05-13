// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { SMARTSystem } from "./SMARTSystem.sol";
import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract SMARTFactory is ERC2771Context {
    constructor(address forwarder) ERC2771Context(forwarder) { }

    function createSystem() public {
        new SMARTSystem(_msgSender(), trustedForwarder());
    }
}
