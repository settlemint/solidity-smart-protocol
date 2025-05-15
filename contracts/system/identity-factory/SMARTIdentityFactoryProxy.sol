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

contract SMARTIdentityFactoryProxy is Proxy {
    ISMARTSystem private _system;

    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
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

    function _implementation() internal view override returns (address) {
        return _system.identityFactoryImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
