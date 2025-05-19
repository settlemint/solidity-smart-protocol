// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTTrustedIssuersRegistryImplementation } from "./SMARTTrustedIssuersRegistryImplementation.sol";
import {
    InitializationFailed,
    TrustedIssuersRegistryImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

/// @title Proxy Contract for SMART Trusted Issuers Registry
/// @author SettleMint Tokenization Services
/// @notice This contract serves as a UUPS (Universal Upgradeable Proxy Standard) compliant proxy for the
/// `SMARTTrustedIssuersRegistryImplementation` contract. It enables the underlying logic of the trusted issuers
/// registry to be upgraded without changing the publicly-facing contract address or losing the stored data.
/// @dev This proxy contract itself does not contain the core business logic for managing trusted issuers. Instead, it
/// delegates all calls (except for a few administrative functions like `_implementation()`) to a specific
/// implementation contract, whose address is retrieved from an `ISMARTSystem` contract.
/// The `ISMARTSystem` contract acts as a central registry for the addresses of various components of the SMART
/// Protocol, including the current logic contract for the trusted issuers registry.
/// During construction, this proxy initializes the implementation contract by delegate-calling its `initialize`
/// function. This ensures that the implementation is set up correctly when the proxy is first deployed.
/// The UUPS pattern means that the upgrade logic itself is part of the implementation contract, not the proxy.
/// This proxy primarily focuses on forwarding calls and ensuring that Ether transfers are not accidentally accepted.
contract SMARTTrustedIssuersRegistryProxy is Proxy {
    // ISMARTSystem private _system; // This was the old way of storing the system address.
    // It's replaced by using a specific storage slot to avoid collisions with implementation storage.

    /// @notice A constant representing the EIP-1936 storage slot where the address of the `ISMARTSystem`
    /// contract is stored. This specific slot is chosen to avoid clashes with storage variables in the
    /// implementation contract, a common concern in upgradeable proxy patterns.
    /// @dev The value is `keccak256("org.smart.contracts.proxy.SMARTTrustedIssuersRegistryProxy.system")`.
    /// Using a namespaced slot like this is a best practice for upgradeable contracts to ensure that proxy storage
    /// does not overlap with implementation storage.
    bytes32 private constant _SYSTEM_SLOT = 0x6fdD361b4a051470236ba6ce1ab028e722825f0fa1553913cf9758f4e87c015e;

    /// @dev Internal function to securely store the address of the `ISMARTSystem` contract in the predefined
    /// `_SYSTEM_SLOT`.
    /// @param system_ The `ISMARTSystem` contract instance whose address needs to be stored.
    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    /// @dev Internal function to retrieve the address of the `ISMARTSystem` contract from the predefined
    /// `_SYSTEM_SLOT` and return it as an `ISMARTSystem` interface type.
    /// @return An `ISMARTSystem` instance pointing to the stored system contract address.
    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructs the `SMARTTrustedIssuersRegistryProxy`.
    /// @dev This constructor performs several critical setup steps:
    /// 1.  Validates the provided `systemAddress`:
    ///     - It must not be the zero address.
    ///     - It must support the `ISMARTSystem` interface (checked via ERC165 `supportsInterface`).
    ///     If validation fails, it reverts with `InvalidSystemAddress`.
    /// 2.  Stores the validated `systemAddress` in the `_SYSTEM_SLOT` using `_setSystem`.
    /// 3.  Retrieves the address of the `SMARTTrustedIssuersRegistryImplementation` logic contract from the
    ///     `ISMARTSystem` contract via `system_.trustedIssuersRegistryImplementation()`.
    ///     If the implementation address is zero (not set in the system contract), it reverts with
    ///     `TrustedIssuersRegistryImplementationNotSet`.
    /// 4.  Prepares the calldata for the `initialize` function of the `SMARTTrustedIssuersRegistryImplementation`.
    ///     This function typically sets up roles and initial state for the trusted issuers registry logic.
    /// 5.  Performs a `delegatecall` to the `initialize` function on the implementation contract. `delegatecall`
    /// ensures
    ///     that the initialization logic runs in the context of this proxy contract, so state changes made by
    ///     `initialize` are stored within the proxy's storage.
    ///     If the `delegatecall` to `initialize` fails (returns `success == false`), it reverts with
    ///     `InitializationFailed`.
    /// @param systemAddress The address of the `ISMARTSystem` contract. This system contract is responsible for
    /// providing the correct address of the trusted issuers registry implementation contract.
    /// @param initialAdmin The address that will be set up with administrative privileges (e.g., `DEFAULT_ADMIN_ROLE`
    /// and `REGISTRAR_ROLE`) within the trusted issuers registry implementation during its initialization.
    constructor(address systemAddress, address initialAdmin) {
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.trustedIssuersRegistryImplementation();
        if (implementation == address(0)) revert TrustedIssuersRegistryImplementationNotSet();

        // Prepare the data for the delegatecall to the implementation's initialize function.
        // This includes the function selector and the arguments.
        bytes memory data =
            abi.encodeWithSelector(SMARTTrustedIssuersRegistryImplementation.initialize.selector, initialAdmin);

        // Perform the delegatecall to initialize the implementation contract in the context of this proxy.
        // slither-disable-next-line low-level-calls: delegatecall is inherent to proxy functionality.
        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed(); // Revert if initialization of the implementation failed.
    }

    /// @notice Returns the address of the current trusted issuers registry implementation contract to which this proxy
    /// delegates calls.
    /// @dev This function is a core part of the EIP-1967 proxy standard (though UUPS proxies like this one manage
    /// upgrades differently, the concept of an implementation address is still central).
    /// It retrieves the `ISMARTSystem` contract address using `_getSystem()` and then calls
    /// `trustedIssuersRegistryImplementation()` on it to get the current logic contract address.
    /// The `Proxy` base contract from OpenZeppelin uses this function to determine where to forward calls.
    /// @return implementationAddress The address of the `SMARTTrustedIssuersRegistryImplementation` contract that
    /// currently holds the business logic.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        return system_.trustedIssuersRegistryImplementation();
    }

    /// @notice Fallback function to reject any direct Ether transfers to this proxy contract.
    /// @dev Proxy contracts, especially those not designed to hold Ether for specific purposes (like this one), should
    /// generally not accept Ether directly. This `receive()` fallback is payable but immediately reverts with
    /// `ETHTransfersNotAllowed`. This prevents accidental Ether locking in the proxy contract.
    /// If Ether needs to be handled, it should typically be done by specific functions in the implementation contract.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
