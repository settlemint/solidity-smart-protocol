// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTComplianceImplementation } from "./SMARTComplianceImplementation.sol";
import {
    InitializationFailed,
    ComplianceImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

/// @title Proxy contract for SMART Compliance.
/// @notice This contract serves as a proxy to the SMART Compliance implementation,
/// allowing for upgradeability of the compliance logic.
/// It retrieves the implementation address from the ISMARTSystem contract.
contract SMARTComplianceProxy is Proxy {
    // keccak256("org.smart.contracts.proxy.SMARTComplianceProxy.system")
    bytes32 private constant _SYSTEM_SLOT = 0x3c9a03fd17b2e1a4f04e739ba7ecf5b4195f2c7c8e2206e09c6426c1b549df2b;

    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructs the SMARTComplianceProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the compliance implementation.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    constructor(address systemAddress) payable {
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.complianceImplementation();

        if (implementation == address(0)) revert ComplianceImplementationNotSet();

        bytes memory data = abi.encodeWithSelector(SMARTComplianceImplementation.initialize.selector);

        // slither-disable-next-line low-level-calls
        (bool success,) = implementation.delegatecall(data);

        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current compliance implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the compliance implementation contract.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        return system_.complianceImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
