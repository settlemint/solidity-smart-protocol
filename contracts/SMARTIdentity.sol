// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import { Identity } from "@onchainid/contracts/Identity.sol";

contract SMARTIdentity is Identity {
    constructor(address initialManagementKey, bool _isLibrary) Identity(initialManagementKey, _isLibrary) { }
}
