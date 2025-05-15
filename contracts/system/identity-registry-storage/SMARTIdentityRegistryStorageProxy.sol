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

/// @title Proxy contract for SMART Identity Registry Storage.
/// @notice This contract serves as a proxy to the SMART Identity Registry Storage implementation,
/// allowing for upgradeability of the storage logic for the identity registry.
/// It retrieves the implementation address from the ISMARTSystem contract.
contract SMARTIdentityRegistryStorageProxy is Proxy {
    ISMARTSystem private _system;

    /// @notice Constructs the SMARTIdentityRegistryStorageProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the identity registry storage implementation.
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

    /// @notice Returns the address of the current identity registry storage implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the identity registry storage implementation contract.
    function _implementation() internal view override returns (address) {
        return _system.identityRegistryStorageImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
