// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { SMARTTokenRegistryImplementation } from "../tokens-registry/SMARTTokenRegistryImplementation.sol";
import { SMARTBondImplementation } from "./SMARTBondImplementation.sol";

contract SMARTBond is Proxy {
    SMARTTokenRegistryImplementation private _registry;

    constructor(address registry, string memory name, string memory symbol, address initialAdmin) {
        _registry = SMARTTokenRegistryImplementation(registry);
        ERC1967Utils.upgradeBeaconToAndCall(
            registry, abi.encodeWithSelector(SMARTBondImplementation.initialize.selector, name, symbol, initialAdmin)
        );
    }

    function _implementation() internal view override returns (address) {
        return _registry.bondImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert("ETH transfers are not allowed");
    }
}
