// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTIdentityRegistryImplementation } from "./SMARTIdentityRegistryImplementation.sol";
import { InitializationFailed, IdentityRegistryImplementationNotSet } from "../SMARTSystemErrors.sol";

contract SMARTIdentityRegistryProxy is Proxy {
    ISMARTSystem private _system;

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

    function _implementation() internal view override returns (address) {
        return _system.identityRegistryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert("ETH transfers are not allowed");
    }
}
