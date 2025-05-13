// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC2771Context, Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { SMARTSystem } from "../SMARTSystem.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { SMARTTokenRegistryImplementation } from "./SMARTTokenRegistryImplementation.sol";

contract SMARTTokenRegistry is Proxy {
    SMARTSystem private _system;

    constructor(address system) {
        _system = SMARTSystem(system);
        ERC1967Utils.upgradeBeaconToAndCall(system, "");
    }

    function _implementation() internal view override returns (address) {
        return _system.tokenRegistryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert("ETH transfers are not allowed");
    }
}
