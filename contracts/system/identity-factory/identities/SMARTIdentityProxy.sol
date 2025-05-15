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

/// @title Proxy contract for SMART Identity.
/// @notice This contract serves as a proxy to the SMART Identity implementation,
/// allowing for upgradeability of the identity logic. It is based on the ERC725 standard.
/// It retrieves the implementation address from the ISMARTSystem contract.
contract SMARTIdentityProxy is Proxy {
    ISMARTSystem private _system;

    /// @dev constructor of the proxy Identity contract
    /// @param systemAddress The address of the ISMARTSystem contract.
    /// @param initialManagementKey The initial management key for the identity.
    /// @notice The proxy will use the logic deployed on the implementation contract,
    /// whose address is listed in the ISMARTSystem contract.
    constructor(address systemAddress, address initialManagementKey) {
        if (systemAddress == address(0)) revert InvalidSystemAddress();
        _system = ISMARTSystem(systemAddress);

        if (initialManagementKey == address(0)) revert ZeroAddressNotAllowed();

        address implementation = _system.identityImplementation();
        if (implementation == address(0)) revert IdentityImplementationNotSet();

        bytes memory data = abi.encodeWithSelector(Identity.initialize.selector, initialManagementKey);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current identity implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the identity implementation contract.
    function _implementation() internal view override returns (address) {
        return _system.identityImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
