// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { ISMARTSystem } from "../../ISMARTSystem.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {
    InitializationFailed,
    IdentityImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../../SMARTSystemErrors.sol";
import { ZeroAddressNotAllowed } from "../SMARTIdentityErrors.sol";
import { Identity } from "@onchainid/contracts/Identity.sol";

/// @title Proxy contract for SMART Token Identity.
/// @notice This contract serves as a proxy to the SMART Token Identity implementation,
/// allowing for upgradeability of the token-bound identity logic. It is based on the ERC725 standard.
/// It retrieves the implementation address from the ISMARTSystem contract.
contract SMARTTokenIdentityProxy is Proxy {
    // ISMARTSystem private _system; // Replaced by StorageSlot

    // keccak256("org.smart.contracts.proxy.SMARTTokenIdentityProxy.system")
    bytes32 private constant _SYSTEM_SLOT = 0x4daB14fe28c3f2b5015f84ab98dd06c520603d8d9f3317f1ae7537d2c65aef3c;

    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @dev Constructor of the proxy Token Identity contract.
    /// @param systemAddress The address of the ISMARTSystem contract.
    /// @param initialManagementKey The initial management key for the token identity.
    /// @notice The proxy will use the logic deployed on the implementation contract
    /// (tokenIdentityImplementation) whose address is listed in the ISMARTSystem contract.
    constructor(address systemAddress, address initialManagementKey) {
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));

        if (initialManagementKey == address(0)) revert ZeroAddressNotAllowed();

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.tokenIdentityImplementation();
        if (implementation == address(0)) revert IdentityImplementationNotSet();

        bytes memory data = abi.encodeWithSelector(Identity.initialize.selector, initialManagementKey);

        // slither-disable-next-line low-level-calls
        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current token identity implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the token identity implementation contract.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        return system_.tokenIdentityImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
