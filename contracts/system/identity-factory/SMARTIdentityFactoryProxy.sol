// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTIdentityFactoryImplementation } from "./SMARTIdentityFactoryImplementation.sol";
import {
    InitializationFailed,
    IdentityFactoryImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

/// @title Proxy contract for SMART Identity Factory.
/// @notice This contract serves as a proxy to the SMART Identity Factory implementation,
/// allowing for upgradeability of the identity factory logic.
/// It retrieves the implementation address from the ISMARTSystem contract.
contract SMARTIdentityFactoryProxy is Proxy {
    // ISMARTSystem private _system; // Replaced by StorageSlot

    // keccak256("org.smart.contracts.proxy.SMARTIdentityFactoryProxy.system")
    bytes32 private constant _SYSTEM_SLOT = 0x1a78f18b10619605209b8a247cac60491f01062a0a3901787532e80d6c2986c0;

    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructs the SMARTIdentityFactoryProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the identity factory implementation.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param initialAdmin The address to be set as the initial admin for the identity factory.
    constructor(address systemAddress, address initialAdmin) {
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.identityFactoryImplementation();
        if (implementation == address(0)) revert IdentityFactoryImplementationNotSet();

        bytes memory data =
            abi.encodeWithSelector(SMARTIdentityFactoryImplementation.initialize.selector, systemAddress, initialAdmin);

        // slither-disable-next-line low-level-calls
        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current identity factory implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the identity factory implementation contract.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        return system_.identityFactoryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
