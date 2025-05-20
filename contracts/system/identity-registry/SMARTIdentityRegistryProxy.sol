// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTIdentityRegistryImplementation } from "./SMARTIdentityRegistryImplementation.sol";
import {
    IdentityRegistryImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

/// @title SMART Identity Registry Proxy
/// @author SettleMint Tokenization Services
/// @notice This contract acts as an EIP-1967 compliant proxy for the `SMARTIdentityRegistryImplementation` contract.
/// It enables the identity registry's logic to be upgraded without changing the contract address that users and other
/// contracts interact with. The address of the current implementation is fetched from a central `ISMARTSystem`
/// contract.
/// @dev This proxy inherits from OpenZeppelin's `Proxy` contract. It stores a reference to the `ISMARTSystem`
/// contract in a specific storage slot to avoid collisions with the implementation's storage.
/// During construction, it initializes the first implementation contract by delegate-calling its `initialize` function.
/// All other calls are delegated to the current implementation address provided by the `ISMARTSystem` contract.
contract SMARTIdentityRegistryProxy is Proxy {
    /// @dev This is a unique storage slot (calculated as `bytes32(uint256(keccak256('eip1967.proxy.system')) - 1)`)
    /// used to store the address of the `ISMARTSystem` contract.
    /// Using a specific slot helps prevent storage collisions between the proxy and the implementation contract,
    /// and clearly identifies where system-critical configuration is stored within the proxy itself.
    bytes32 private constant _SYSTEM_SLOT = 0x524f57074757cf9111a710840ae36621195c9e71b86a3677158783402f22b8f8;

    /// @notice Internal function to set the address of the `ISMARTSystem` contract.
    /// @dev This function directly writes the `system_` address to the `_SYSTEM_SLOT`.
    /// It should only be callable during the proxy's construction or by a future upgrade mechanism if designed.
    /// @param system_ The address of the `ISMARTSystem` contract.
    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    /// @notice Internal function to retrieve the address of the `ISMARTSystem` contract.
    /// @dev This function reads the address stored in `_SYSTEM_SLOT` and casts it to the `ISMARTSystem` interface.
    /// @return ISMARTSystem The instance of the `ISMARTSystem` contract.
    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructs the `SMARTIdentityRegistryProxy`.
    /// @dev This constructor performs several critical setup steps:
    /// 1. Validates the `systemAddress`: Ensures it's not a zero address and that it supports the `ISMARTSystem`
    /// interface (ERC165 check).
    ///    Reverts with `InvalidSystemAddress` if validation fails.
    /// 2. Stores the `systemAddress` in the `_SYSTEM_SLOT` using `_setSystem()`.
    /// 3. Retrieves the `SMARTIdentityRegistryImplementation` address from the `ISMARTSystem` contract.
    ///    Reverts with `IdentityRegistryImplementationNotSet` if the implementation address is zero.
    /// 4. Encodes the call data for the `initialize` function of the `SMARTIdentityRegistryImplementation`.
    ///    This includes `initialAdmin`, `identityStorage`, and `trustedIssuersRegistry` parameters.
    /// 5. Performs a `delegatecall` to the implementation contract with the encoded initialization data.
    ///    This executes the `initialize` function in the context of the proxy, setting up the initial state.
    ///    Reverts with `InitializationFailed` if the `delegatecall` is unsuccessful.
    /// The constructor is `payable` to allow for potential ETH transfers during deployment if needed by the underlying
    /// logic,
    /// though typically proxy constructors themselves don't require ETH unless the initializer does.
    /// @param systemAddress The address of the `ISMARTSystem` contract. This contract is responsible for providing
    /// the address of the current `SMARTIdentityRegistryImplementation` logic contract.
    /// @param initialAdmin The address that will be granted the `DEFAULT_ADMIN_ROLE` and `REGISTRAR_ROLE`
    /// in the `SMARTIdentityRegistryImplementation` during its initialization.
    /// @param identityStorage The address of the `IERC3643IdentityRegistryStorage` contract to be used by the identity
    /// registry.
    /// @param trustedIssuersRegistry The address of the `IERC3643TrustedIssuersRegistry` contract to be used by the
    /// identity registry.
    constructor(
        address systemAddress,
        address initialAdmin,
        address identityStorage,
        address trustedIssuersRegistry
    )
        payable // Allows constructor to receive ETH if initialization logic requires it.
    {
        // Validate that the provided systemAddress is a valid contract supporting ISMARTSystem interface.
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        // Store the system address in the designated storage slot.
        _setSystem(ISMARTSystem(systemAddress));

        // Retrieve the ISMARTSystem contract instance and get the implementation address.
        ISMARTSystem system = _getSystem();
        address implementation = system.identityRegistryImplementation();
        // Ensure an implementation address is actually set in the system contract.
        if (implementation == address(0)) revert IdentityRegistryImplementationNotSet();

        // Prepare the calldata for the initialize function of the implementation contract.
        bytes memory data = abi.encodeWithSelector(
            SMARTIdentityRegistryImplementation.initialize.selector,
            initialAdmin,
            identityStorage,
            trustedIssuersRegistry
        );

        // Perform the delegatecall to initialize the identity logic in the context of this proxy's storage.
        // slither-disable-next-line low-level-calls: Delegatecall is inherent and fundamental to proxy functionality.
        (bool success, bytes memory returnData) = implementation.delegatecall(data);
        if (!success) {
            // Revert with the original error message from the implementation
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }

    /// @notice Returns the address of the current identity registry logic contract (implementation).
    /// @dev This function is a core part of the EIP-1967 proxy standard. It is called internally by the
    /// `Proxy` base contract (and its fallback function) to determine where to delegate incoming calls.
    /// It retrieves the implementation address from the `ISMARTSystem` contract via `_getSystem()`.
    /// @return implementationAddress The address of the current `SMARTIdentityRegistryImplementation` contract.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system = _getSystem();
        // Fetch the current implementation address from the central SMARTSystem contract.
        return system.identityRegistryImplementation();
    }

    /// @notice The `receive` function is declared `external payable` to handle plain Ether transfers to the proxy.
    /// @dev By default, this proxy contract explicitly rejects any direct Ether transfers by reverting with
    /// `ETHTransfersNotAllowed`. This is a safety measure, as proxies themselves usually don't need to hold ETH
    /// unless the underlying implementation logic is designed to handle it (e.g., via a payable fallback or other
    /// functions).
    /// If the implementation contract is intended to receive ETH, it should have its own payable functions.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
