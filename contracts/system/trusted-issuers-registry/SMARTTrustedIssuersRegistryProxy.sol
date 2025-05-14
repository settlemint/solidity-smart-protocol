// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTTrustedIssuersRegistryImplementation } from "./SMARTTrustedIssuersRegistryImplementation.sol";
import { InitializationFailed, TrustedIssuersRegistryImplementationNotSet } from "../SMARTSystemErrors.sol";

contract SMARTTrustedIssuersRegistryProxy is Proxy {
    ISMARTSystem private _system;

    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param initialAdmin The address for initial admin and registrar roles.
    constructor(address systemAddress, address initialAdmin) payable {
        _system = ISMARTSystem(systemAddress);

        address implementation = _system.trustedIssuersRegistryImplementation();
        if (implementation == address(0)) revert TrustedIssuersRegistryImplementationNotSet();

        bytes memory data =
            abi.encodeWithSelector(SMARTTrustedIssuersRegistryImplementation.initialize.selector, initialAdmin);

        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    function _implementation() internal view override returns (address) {
        return _system.trustedIssuersRegistryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert("ETH transfers are not allowed");
    }
}
