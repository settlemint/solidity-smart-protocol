// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTIdentityRegistryStorageImplementation } from "./SMARTIdentityRegistryStorageImplementation.sol";
import {
    InitializationFailed,
    IdentityRegistryStorageImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

/// @title SMART Identity Registry Storage Proxy
/// @author SettleMint Tokenization Services
/// @notice This contract serves as an EIP-1967 compliant proxy for the `SMARTIdentityRegistryStorageImplementation`
/// contract.
/// It allows the underlying storage logic for the identity registry to be upgraded without changing the publicly-facing
/// contract address.
/// The address of the current storage implementation is dynamically fetched from a central `ISMARTSystem` contract.
/// @dev This proxy inherits from OpenZeppelin's `Proxy` contract. It uses a dedicated storage slot (`_SYSTEM_SLOT`)
/// to store the address of the `ISMARTSystem` contract, which prevents storage layout collisions with the
/// `SMARTIdentityRegistryStorageImplementation` contract that this proxy delegates to.
/// During its construction, the proxy initializes the first version of the storage implementation by performing a
/// `delegatecall`
/// to its `initialize` function. All subsequent calls to this proxy are then delegated to the current implementation
/// address
/// as specified by the `ISMARTSystem` contract.
contract SMARTIdentityRegistryStorageProxy is Proxy {
    /// @dev A unique storage slot identifier used to store the address of the `ISMARTSystem` contract.
    /// This specific slot (`keccak256("org.smart.contracts.proxy.SMARTIdentityRegistryStorageProxy.system")`) is chosen
    /// to be distinct and avoid clashes with storage variables in the implementation contract or other proxy-related
    /// slots.
    /// Storing the system address here allows the proxy to dynamically find the correct implementation address.
    bytes32 private constant _SYSTEM_SLOT = 0x5ebC250a39d4036f126095bd09ef17d621714e9ea0442802bf8647e3d76bf04d;

    /// @notice Internal function to set the address of the `ISMARTSystem` contract in its dedicated storage slot.
    /// @dev This function is called during the proxy's construction to establish the link to the `ISMARTSystem`.
    /// It directly writes the `system_` address to the `_SYSTEM_SLOT` using `StorageSlot.getAddressSlot()`.
    /// @param system_ The address of the `ISMARTSystem` contract.
    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    /// @notice Internal function to retrieve the `ISMARTSystem` contract instance from its dedicated storage slot.
    /// @dev This function reads the address stored in `_SYSTEM_SLOT` and casts it to the `ISMARTSystem` interface type.
    /// It is used internally whenever the proxy needs to interact with the `ISMARTSystem` (e.g., to get the
    /// implementation address).
    /// @return ISMARTSystem The instance of the `ISMARTSystem` contract.
    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructs the `SMARTIdentityRegistryStorageProxy`.
    /// @dev The constructor performs the following critical initialization steps:
    /// 1.  Validates the `systemAddress`: It must not be the zero address and must support the `ISMARTSystem` interface
    /// (checked via ERC165 `supportsInterface`).
    ///     If validation fails, it reverts with `InvalidSystemAddress`.
    /// 2.  Stores the validated `systemAddress` in the `_SYSTEM_SLOT` by calling `_setSystem()`.
    /// 3.  Retrieves the address of the `SMARTIdentityRegistryStorageImplementation` from the `ISMARTSystem` contract.
    ///     If the implementation address is the zero address (not set), it reverts with
    /// `IdentityRegistryStorageImplementationNotSet`.
    /// 4.  Prepares the calldata for the `initialize` function of the `SMARTIdentityRegistryStorageImplementation`.
    ///     This calldata includes the `systemAddress` (for the implementation to know its governing system) and the
    /// `initialAdmin` address.
    /// 5.  Executes a `delegatecall` to the `initialize` function on the implementation contract. This call runs the
    ///     implementation's initialization logic in the storage context of this proxy contract.
    ///     If the `delegatecall` fails (returns `success == false`), it reverts with `InitializationFailed`.
    /// This constructor is *not* `payable`. If the initialization logic of the implementation requires Ether, the
    /// deployment transaction
    /// would need to send Ether directly to the implementation if it were a standalone deployment, or the factory
    /// deploying this proxy
    /// would need to handle it if ETH is required during the `delegatecall` to `initialize`.
    /// @param systemAddress The address of the `ISMARTSystem` contract. This contract is responsible for providing
    /// the address of the current `SMARTIdentityRegistryStorageImplementation` logic contract.
    /// @param initialAdmin The address that will be granted the `DEFAULT_ADMIN_ROLE` (and other initial roles as
    /// defined
    /// in the implementation's `initialize` function) within the storage implementation.
    constructor(address systemAddress, address initialAdmin) {
        // Ensure the provided systemAddress is valid and implements the ISMARTSystem interface.
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        // Store the system address in its designated slot.
        _setSystem(ISMARTSystem(systemAddress));

        // Retrieve the ISMARTSystem instance and then get the storage implementation address from it.
        ISMARTSystem system_ = _getSystem();
        address implementation = system_.identityRegistryStorageImplementation();
        // Ensure that the system contract returned a valid implementation address.
        if (implementation == address(0)) revert IdentityRegistryStorageImplementationNotSet();

        // Prepare the data for the delegatecall to the implementation's initialize function.
        // This includes the selector of `SMARTIdentityRegistryStorageImplementation.initialize` and its arguments.
        bytes memory data = abi.encodeWithSelector(
            SMARTIdentityRegistryStorageImplementation.initialize.selector, systemAddress, initialAdmin
        );

        // Perform the delegatecall to initialize the implementation in the context of this proxy.
        // slither-disable-next-line low-level-calls (Delegatecall is a fundamental part of the proxy pattern)
        (bool success,) = implementation.delegatecall(data);
        // If the initialization via delegatecall failed, revert the proxy deployment.
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current `SMARTIdentityRegistryStorageImplementation` logic contract.
    /// @dev This function is a core part of the EIP-1967 proxy standard. It is called internally by the `Proxy`
    /// base contract's fallback mechanism to determine where to delegate all incoming calls.
    /// It retrieves the `ISMARTSystem` instance using `_getSystem()` and then queries it for the current
    /// identity registry storage implementation address.
    /// @return implementationAddress The address of the current logic contract for the identity registry storage.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        // Dynamically fetch the latest implementation address from the SMARTSystem contract.
        return system_.identityRegistryStorageImplementation();
    }

    /// @notice Fallback `receive` function to handle direct Ether transfers to this proxy contract.
    /// @dev This function is intentionally designed to revert all direct Ether transfers to the proxy
    /// by throwing an `ETHTransfersNotAllowed` error. This is a safety precaution, as proxy contracts
    /// themselves typically do not need to hold Ether. If the underlying implementation logic
    /// requires Ether, it should be sent via payable functions defined in that implementation,
    /// which will then be executed in the context of this proxy via `delegatecall`.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
