// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
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
    ISMARTSystem private _system;

    /// @notice Constructs the SMARTComplianceProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the compliance implementation.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    constructor(address systemAddress) payable {
        if (systemAddress == address(0)) revert InvalidSystemAddress();
        _system = ISMARTSystem(systemAddress);

        address implementation = _system.complianceImplementation();
        if (implementation == address(0)) revert ComplianceImplementationNotSet();

        bytes memory data = abi.encodeWithSelector(SMARTComplianceImplementation.initialize.selector);

        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current compliance implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the compliance implementation contract.
    function _implementation() internal view override returns (address) {
        return _system.complianceImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
