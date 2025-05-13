// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { SMARTSystem } from "../SMARTSystem.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { SMARTComplianceImplementation } from "./SMARTComplianceImplementation.sol";

contract SMARTCompliance is Proxy {
    SMARTSystem private _system;

    constructor(address system) {
        _system = SMARTSystem(system);
        ERC1967Utils.upgradeBeaconToAndCall(system, "");
    }

    function _implementation() internal view override returns (address) {
        return _system.complianceImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert("ETH transfers are not allowed");
    }
}
