// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import { Identity } from "@onchainid/contracts/Identity.sol";

contract SMARTIdentityImplementation is Identity {
    constructor(address initialManagementKey, bool _isLibrary) Identity(initialManagementKey, _isLibrary) { }
}
