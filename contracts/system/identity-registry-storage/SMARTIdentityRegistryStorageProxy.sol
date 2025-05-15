// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTIdentityRegistryStorageImplementation } from "./SMARTIdentityRegistryStorageImplementation.sol";
import {
    InitializationFailed,
    IdentityRegistryStorageImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

contract SMARTIdentityRegistryStorageProxy is Proxy {
    ISMARTSystem private _system;

    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param initialAdmin The address for initial admin and registrar roles.
    constructor(address systemAddress, address initialAdmin) payable {
        if (systemAddress == address(0)) revert InvalidSystemAddress();
        _system = ISMARTSystem(systemAddress);

        address implementation = _system.identityRegistryStorageImplementation();
        if (implementation == address(0)) revert IdentityRegistryStorageImplementationNotSet();

        bytes memory data =
            abi.encodeWithSelector(SMARTIdentityRegistryStorageImplementation.initialize.selector, initialAdmin);

        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    function _implementation() internal view override returns (address) {
        return _system.identityRegistryStorageImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
