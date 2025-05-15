// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
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
    ISMARTSystem private _system;

    /// @notice Constructs the SMARTIdentityFactoryProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the identity factory implementation.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param initialAdmin The address to be set as the initial admin for the identity factory.
    constructor(address systemAddress, address initialAdmin) payable {
        if (systemAddress == address(0)) revert InvalidSystemAddress();
        _system = ISMARTSystem(systemAddress);

        address implementation = _system.identityFactoryImplementation();
        if (implementation == address(0)) revert IdentityFactoryImplementationNotSet();

        bytes memory data =
            abi.encodeWithSelector(SMARTIdentityFactoryImplementation.initialize.selector, systemAddress, initialAdmin);

        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current identity factory implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the identity factory implementation contract.
    function _implementation() internal view override returns (address) {
        return _system.identityFactoryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
