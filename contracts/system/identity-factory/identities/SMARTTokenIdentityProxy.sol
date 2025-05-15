// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import { ISMARTSystem } from "../../ISMARTSystem.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import {
    InitializationFailed,
    IdentityImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../../SMARTSystemErrors.sol";
import { ZeroAddressNotAllowed } from "../SMARTIdentityErrors.sol";
import { Identity } from "@onchainid/contracts/Identity.sol";

contract SMARTIdentityProxy is Proxy {
    ISMARTSystem private _system;

    /**
     *  @dev constructor of the proxy Identity contract
     *  @param systemAddress the implementation Authority contract address
     *  @param initialManagementKey the management key at deployment
     *  the proxy is going to use the logic deployed on the implementation contract
     *  deployed at an address listed in the ImplementationAuthority contract
     */
    constructor(address systemAddress, address initialManagementKey) {
        if (systemAddress == address(0)) revert InvalidSystemAddress();
        _system = ISMARTSystem(systemAddress);

        if (initialManagementKey == address(0)) revert ZeroAddressNotAllowed();

        address implementation = _system.tokenIdentityImplementation();
        if (implementation == address(0)) revert IdentityImplementationNotSet();

        bytes memory data = abi.encodeWithSelector(Identity.initialize.selector, initialManagementKey);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    function _implementation() internal view override returns (address) {
        return _system.tokenIdentityImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
