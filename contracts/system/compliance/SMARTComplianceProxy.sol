// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTComplianceImplementation } from "./SMARTComplianceImplementation.sol";
import { InitializationFailed, ComplianceImplementationNotSet } from "../SMARTSystemErrors.sol";

contract SMARTComplianceProxy is Proxy {
    ISMARTSystem private _system;

    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    constructor(address systemAddress) payable {
        _system = ISMARTSystem(systemAddress);

        address implementation = _system.complianceImplementation();
        if (implementation == address(0)) revert ComplianceImplementationNotSet();

        bytes memory data = abi.encodeWithSelector(SMARTComplianceImplementation.initialize.selector);

        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    function _implementation() internal view override returns (address) {
        return _system.complianceImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert("ETH transfers are not allowed");
    }
}
