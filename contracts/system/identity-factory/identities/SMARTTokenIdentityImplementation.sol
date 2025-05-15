// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import { Identity } from "@onchainid/contracts/Identity.sol";

// TODO: fix this so that it can be managed by the tokens Access Control
contract SMARTTokenIdentityImplementation is Identity {
    constructor(address initialManagementKey, bool _isLibrary) Identity(initialManagementKey, _isLibrary) { }
}
