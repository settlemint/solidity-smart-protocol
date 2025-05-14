// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";

contract SMARTIdentityFactoryProxy is Proxy {
    ISMARTSystem private _system;

    /**
     * @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
     */
    constructor(address systemAddress, address initialAdmin) payable {
        _system = ISMARTSystem(systemAddress);

        address implementation = _system.complianceImplementation();
        require(implementation != address(0), "SMARTComplianceProxy: implementation not set in system");

        bytes memory data = abi.encodeWithSelector(SMARTComplianceImplementation.initialize.selector, initialAdmin);

        (bool success,) = implementation.delegatecall(data);
        require(success, "SMARTComplianceProxy: initializer call failed");
    }

    function _implementation() internal view override returns (address) {
        return _system.identityFactoryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert("ETH transfers are not allowed");
    }
}
