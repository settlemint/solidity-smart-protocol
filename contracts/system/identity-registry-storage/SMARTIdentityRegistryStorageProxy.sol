// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
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
    // ISMARTSystem private _system; // Replaced by StorageSlot

    // keccak256("org.smart.contracts.proxy.SMARTIdentityRegistryStorageProxy.system")
    bytes32 private constant _SYSTEM_SLOT = 0x5ebC250a39d4036f126095bd09ef17d621714e9ea0442802bf8647e3d76bf04d;

    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructs the SMARTIdentityRegistryStorageProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the identity registry storage implementation.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param initialAdmin The address for initial admin and registrar roles.
    constructor(address systemAddress, address initialAdmin) {
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.identityRegistryStorageImplementation();
        if (implementation == address(0)) revert IdentityRegistryStorageImplementationNotSet();

        bytes memory data = abi.encodeWithSelector(
            SMARTIdentityRegistryStorageImplementation.initialize.selector, systemAddress, initialAdmin
        );

        // slither-disable-next-line low-level-calls
        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current identity registry storage implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the identity registry storage implementation contract.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        return system_.identityRegistryStorageImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
