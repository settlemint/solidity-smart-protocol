// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTTrustedIssuersRegistryImplementation } from "./SMARTTrustedIssuersRegistryImplementation.sol";
import {
    InitializationFailed,
    TrustedIssuersRegistryImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

/// @title Proxy contract for SMART Trusted Issuers Registry.
/// @notice This contract serves as a proxy to the SMART Trusted Issuers Registry implementation,
/// allowing for upgradeability of the trusted issuers registry logic.
/// It retrieves the implementation address from the ISMARTSystem contract.
contract SMARTTrustedIssuersRegistryProxy is Proxy {
    ISMARTSystem private _system;

    /// @notice Constructs the SMARTTrustedIssuersRegistryProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the trusted issuers registry implementation.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param initialAdmin The address for initial admin and registrar roles.
    constructor(address systemAddress, address initialAdmin) payable {
        if (systemAddress == address(0)) revert InvalidSystemAddress();
        _system = ISMARTSystem(systemAddress);

        address implementation = _system.trustedIssuersRegistryImplementation();
        if (implementation == address(0)) revert TrustedIssuersRegistryImplementationNotSet();

        bytes memory data =
            abi.encodeWithSelector(SMARTTrustedIssuersRegistryImplementation.initialize.selector, initialAdmin);

        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current trusted issuers registry implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the trusted issuers registry implementation contract.
    function _implementation() internal view override returns (address) {
        return _system.trustedIssuersRegistryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
