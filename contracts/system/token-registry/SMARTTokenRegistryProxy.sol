// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { ISMARTTokenRegistry } from "./ISMARTTokenRegistry.sol";
import {
    InitializationFailed,
    IdentityFactoryImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed,
    TokenRegistryImplementationNotSet
} from "../SMARTSystemErrors.sol";

/// @title Proxy contract for SMART Token Registry.
/// @notice This contract serves as a proxy to the SMART Token Registry implementation,
/// allowing for upgradeability of the token registry logic.
/// It retrieves the implementation address from the ISMARTSystem contract.
contract SMARTTokenRegistryProxy is Proxy {
    // keccak256("org.smart.contracts.proxy.SMARTTokenRegistryProxy.system")
    bytes32 private constant _SYSTEM_SLOT = 0x1a78f18b10619605209b8a247cac60491f01062a0a3901787532e80d6c2986c0;

    // keccak256("org.smart.contracts.proxy.SMARTTokenRegistryProxy.registryTypeHash")
    bytes32 private constant _REGISTRY_TYPE_HASH_SLOT =
        0xb0409e08a1a1a7781e4026667a65f26744a8159b687f00cf21f1b8a95961f831;

    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    function _setRegistryTypeHash(bytes32 registryTypeHash_) internal {
        StorageSlot.getBytes32Slot(_REGISTRY_TYPE_HASH_SLOT).value = registryTypeHash_;
    }

    function _getRegistryTypeHash() internal view returns (bytes32) {
        return StorageSlot.getBytes32Slot(_REGISTRY_TYPE_HASH_SLOT).value;
    }

    /// @notice Constructs the SMARTTokenRegistryProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the token registry implementation.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param registryTypeHash The hash of the registry type.
    constructor(address systemAddress, bytes32 registryTypeHash) payable {
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));
        _setRegistryTypeHash(registryTypeHash);

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.tokenRegistryImplementation(registryTypeHash);
        if (implementation == address(0)) revert TokenRegistryImplementationNotSet(registryTypeHash);

        bytes memory data = abi.encodeWithSelector(ISMARTTokenRegistry.initialize.selector);

        // slither-disable-next-line low-level-calls
        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current token registry implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the token registry implementation contract.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        bytes32 registryTypeHash = _getRegistryTypeHash();
        return system_.tokenRegistryImplementation(registryTypeHash);
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
