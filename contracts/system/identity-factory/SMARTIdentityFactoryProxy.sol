// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTIdentityFactoryImplementation } from "./SMARTIdentityFactoryImplementation.sol";
import {
    InitializationFailed,
    IdentityFactoryImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

/// @title SMART Identity Factory Proxy Contract
/// @author SettleMint Tokenization Services
/// @notice This contract acts as an upgradeable proxy for the `SMARTIdentityFactoryImplementation`.
/// @dev It follows the EIP-1967 standard for upgradeable proxies. This means that this contract (the proxy)
///      holds the storage and the public address that users interact with, while the logic (code execution)
///      is delegated to a separate implementation contract (`SMARTIdentityFactoryImplementation`).
///      The address of the current implementation contract is retrieved dynamically from the `ISMARTSystem` contract.
///      This allows the underlying identity factory logic to be upgraded without changing the proxy's address or losing
/// its state.
///      Inherits from OpenZeppelin's `Proxy` contract, which handles the low-level `delegatecall`.
contract SMARTIdentityFactoryProxy is Proxy {
    /// @dev Storage slot used to store the address of the `ISMARTSystem` contract, ensuring it doesn't collide with
    /// other storage variables.
    /// This specific slot `0x1a78f18b10619605209b8a247cac60491f01062a0a3901787532e80d6c2986c0` is
    /// `keccak256("org.smart.contracts.proxy.SMARTIdentityFactoryProxy.system")`.
    /// Using a constant, well-defined storage slot is a best practice for upgradeable contracts to prevent storage
    /// layout clashes.
    bytes32 private constant _SYSTEM_SLOT = 0x1a78f18b10619605209b8a247cac60491f01062a0a3901787532e80d6c2986c0;

    /// @notice Internal function to securely store the address of the `ISMARTSystem` contract in the designated storage
    /// slot.
    /// @dev This is typically called once during the proxy's construction.
    /// @param system_ The instance of the `ISMARTSystem` contract to be stored.
    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    /// @notice Internal function to securely retrieve the address of the `ISMARTSystem` contract from its storage slot.
    /// @dev This is used by the proxy to find out which implementation contract to delegate calls to.
    /// @return ISMARTSystem The instance of the `ISMARTSystem` contract currently configured for this proxy.
    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructor for the `SMARTIdentityFactoryProxy`.
    /// @dev This function is called only once when the proxy contract is deployed.
    /// It performs critical setup steps:
    /// 1. Validates the provided `systemAddress`: Ensures it's not the zero address and that it correctly implements
    /// the `ISMARTSystem` interface (checked via ERC165 `supportsInterface`).
    /// 2. Stores the `systemAddress` using `_setSystem` in a specific storage slot.
    /// 3. Retrieves the initial `SMARTIdentityFactoryImplementation` address from the stored `ISMARTSystem` contract.
    /// 4. Ensures this retrieved implementation address is not the zero address (i.e., it's configured in the system).
    /// 5. Executes a `delegatecall` to the `initialize` function of the `SMARTIdentityFactoryImplementation` contract.
    ///    This `initialize` call sets up the initial state of the factory logic *within the storage context of this
    /// proxy*.
    ///    The `initialAdmin` is passed to this `initialize` function to set up initial ownership/roles for the factory.
    ///    If this initialization `delegatecall` fails, the proxy deployment will revert.
    /// @param systemAddress The address of the `ISMARTSystem` contract. This system contract is responsible for
    /// providing the address of the actual identity factory logic (implementation) contract.
    /// @param initialAdmin The address that will be granted initial administrative privileges (e.g.,
    /// `DEFAULT_ADMIN_ROLE`, `REGISTRAR_ROLE`) in the `SMARTIdentityFactoryImplementation` logic contract.
    constructor(address systemAddress, address initialAdmin) {
        // Validate that the provided systemAddress is a valid contract implementing ISMARTSystem
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.identityFactoryImplementation();
        // Ensure the ISMARTSystem contract has an identity factory implementation configured.
        if (implementation == address(0)) revert IdentityFactoryImplementationNotSet();

        // Prepare the call data for the delegatecall to the implementation's initialize function.
        // This calls SMARTIdentityFactoryImplementation.initialize(systemAddress, initialAdmin).
        bytes memory data =
            abi.encodeWithSelector(SMARTIdentityFactoryImplementation.initialize.selector, systemAddress, initialAdmin);

        // Perform the delegatecall to initialize the implementation contract in the context of this proxy's storage.
        // slither-disable-next-line low-level-calls: Delegatecall is inherent and fundamental to proxy functionality.
        (bool success,) = implementation.delegatecall(data);

        // If the initialization call (via delegatecall) failed, revert the proxy deployment.
        if (!success) revert InitializationFailed();
    }

    /// @notice Determines the address of the current logic/implementation contract for the identity factory.
    /// @dev This function is a core part of OpenZeppelin's `Proxy` contract functionality (specifically for EIP-1967
    /// proxies).
    ///      It is called internally by the `Proxy` base contract before every external function call made to this
    /// proxy.
    ///      The `Proxy` then uses the address returned by this function to `delegatecall` the user's request to the
    /// correct logic contract.
    ///      In this specific proxy, the implementation address is dynamically fetched from the `ISMARTSystem` contract
    /// (via `_getSystem()`).
    ///      This allows an administrator of the `ISMARTSystem` to upgrade the identity factory logic system-wide by
    /// updating the
    ///      address returned by `system_.identityFactoryImplementation()`.
    /// @return address The current address of the `SMARTIdentityFactoryImplementation` contract that this proxy should
    /// delegate calls to.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        return system_.identityFactoryImplementation();
    }

    /// @notice Rejects any direct Ether (ETH) transfers to this proxy contract.
    /// @dev Proxy contracts typically should not hold Ether themselves, as their purpose is to manage storage and
    /// delegate calls.
    ///      Any Ether intended for the functionality should be handled by the logic contract if needed.
    ///      The `payable` keyword is required for `receive()` to be valid, but the `revert` ensures no ETH is accepted.
    ///      This helps prevent accidental locking of funds in the proxy.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
