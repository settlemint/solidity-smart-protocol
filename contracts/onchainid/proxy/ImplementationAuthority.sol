// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IImplementationAuthority } from "../interface/IImplementationAuthority.sol";

error ZeroAddressNotAllowed();

contract ImplementationAuthority is IImplementationAuthority, Ownable {
    // the address of implementation of ONCHAINID
    address internal _implementation;

    constructor(address implementation) Ownable(_msgSender()) {
        if (implementation == address(0)) revert ZeroAddressNotAllowed();
        _implementation = implementation;
        emit UpdatedImplementation(implementation);
    }

    /**
     *  @dev See {IImplementationAuthority-updateImplementation}.
     */
    function updateImplementation(address _newImplementation) external override onlyOwner {
        if (_newImplementation == address(0)) revert ZeroAddressNotAllowed();
        _implementation = _newImplementation;
        emit UpdatedImplementation(_newImplementation);
    }

    /**
     *  @dev See {IImplementationAuthority-getImplementation}.
     */
    function getImplementation() external view override returns (address) {
        return _implementation;
    }
}
