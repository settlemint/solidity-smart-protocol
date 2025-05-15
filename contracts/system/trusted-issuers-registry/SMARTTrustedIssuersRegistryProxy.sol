// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
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
    // ISMARTSystem private _system; // Replaced by StorageSlot

    // keccak256("org.smart.contracts.proxy.SMARTTrustedIssuersRegistryProxy.system")
    bytes32 private constant _SYSTEM_SLOT = 0x6fdD361b4a051470236ba6ce1ab028e722825f0fa1553913cf9758f4e87c015e;

    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructs the SMARTTrustedIssuersRegistryProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the trusted issuers registry implementation.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param initialAdmin The address for initial admin and registrar roles.
    constructor(address systemAddress, address initialAdmin) payable {
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.trustedIssuersRegistryImplementation();
        if (implementation == address(0)) revert TrustedIssuersRegistryImplementationNotSet();

        bytes memory data =
            abi.encodeWithSelector(SMARTTrustedIssuersRegistryImplementation.initialize.selector, initialAdmin);

        // slither-disable-next-line low-level-calls
        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current trusted issuers registry implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the trusted issuers registry implementation contract.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        return system_.trustedIssuersRegistryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
