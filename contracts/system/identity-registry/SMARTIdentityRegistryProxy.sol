// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTIdentityRegistryImplementation } from "./SMARTIdentityRegistryImplementation.sol";
import {
    InitializationFailed,
    IdentityRegistryImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

/// @title Proxy contract for SMART Identity Registry.
/// @notice This contract serves as a proxy to the SMART Identity Registry implementation,
/// allowing for upgradeability of the identity registry logic.
/// It retrieves the implementation address from the ISMARTSystem contract.
contract SMARTIdentityRegistryProxy is Proxy {
    ISMARTSystem private _system;

    /// @notice Constructs the SMARTIdentityRegistryProxy.
    /// @dev Initializes the proxy by setting the system address and delegating a call
    /// to the `initialize` function of the identity registry implementation.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param initialAdmin The address for initial admin and registrar roles.
    /// @param identityStorage The address of the `IERC3643IdentityRegistryStorage` contract.
    /// @param trustedIssuersRegistry The address of the `IERC3643TrustedIssuersRegistry` contract.
    constructor(
        address systemAddress,
        address initialAdmin,
        address identityStorage,
        address trustedIssuersRegistry
    )
        payable
    {
        if (systemAddress == address(0)) revert InvalidSystemAddress();
        _system = ISMARTSystem(systemAddress);

        address implementation = _system.identityRegistryImplementation();
        if (implementation == address(0)) revert IdentityRegistryImplementationNotSet();

        bytes memory data = abi.encodeWithSelector(
            SMARTIdentityRegistryImplementation.initialize.selector,
            initialAdmin,
            identityStorage,
            trustedIssuersRegistry
        );

        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current identity registry implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the identity registry implementation contract.
    function _implementation() internal view override returns (address) {
        return _system.identityRegistryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
