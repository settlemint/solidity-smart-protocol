// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import { Identity } from "@onchainid/contracts/Identity.sol";

// TODO: fix this so that it can be managed by the tokens Access Control
// TODO: fix to be ERC-2771 compatible
contract SMARTTokenIdentityImplementation is Identity {
    constructor(address initialManagementKey) Identity(initialManagementKey, true) { }
}
