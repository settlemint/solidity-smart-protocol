// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { SMARTComplianceImplementation } from "./SMARTComplianceImplementation.sol";
import {
    InitializationFailed,
    ComplianceImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../SMARTSystemErrors.sol";

/// @title SMART Compliance Proxy Contract
/// @author SettleMint Tokenization Services
/// @notice This contract acts as an upgradeable proxy for the main SMART Compliance functionality.
/// @dev This proxy follows a pattern where the logic contract (implementation) can be changed without altering
/// the address that users and other contracts interact with. This is crucial for fixing bugs or adding features
/// to the compliance system post-deployment.
/// The address of the actual logic contract (`SMARTComplianceImplementation`) is retrieved from a central
/// `ISMARTSystem` contract. This means the `ISMARTSystem` contract governs which version of the compliance logic is
/// active.
/// This proxy inherits from OpenZeppelin's `Proxy` contract, which handles the low-level `delegatecall` logic
/// to forward calls to the implementation contract while maintaining the proxy's storage, address, and balance.
contract SMARTComplianceProxy is Proxy {
    /// @dev Storage slot used to store the address of the `ISMARTSystem` contract.
    /// Using a specific storage slot helps prevent storage collisions when upgrading the proxy itself or its
    /// implementation.
    /// This is a common pattern in upgradeable contracts.
    /// The value is `keccak256("org.smart.contracts.proxy.SMARTComplianceProxy.system")`.
    bytes32 private constant _SYSTEM_SLOT = 0x3c9a03fd17b2e1a4f04e739ba7ecf5b4195f2c7c8e2206e09c6426c1b549df2b;

    /// @notice Internal function to store the address of the `ISMARTSystem` contract in the designated storage slot.
    /// @dev This function is typically called during the proxy's construction or potentially during an upgrade
    /// if the system contract itself needed to be changed (though this is less common).
    /// It uses `StorageSlot.getAddressSlot` to safely access and write to the specific storage location.
    /// @param system_ The instance of the `ISMARTSystem` contract.
    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    /// @notice Internal function to retrieve the address of the `ISMARTSystem` contract from its storage slot.
    /// @dev This function is used by other functions within the proxy (like `_implementation`) to know where
    /// to look up the current logic contract address.
    /// It uses `StorageSlot.getAddressSlot` to safely read the address.
    /// @return The instance of the `ISMARTSystem` contract currently configured for this proxy.
    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructor for the `SMARTComplianceProxy`.
    /// @dev This function is called only once when the proxy contract is deployed.
    /// Its primary responsibilities are:
    /// 1. Validate the provided `systemAddress`: Ensures it's not the zero address and that it implements the
    /// `ISMARTSystem` interface (via ERC165 check).
    /// 2. Store the `systemAddress` using `_setSystem`.
    /// 3. Retrieve the initial compliance logic implementation address from the `ISMARTSystem` contract.
    /// 4. Ensure the retrieved implementation address is not the zero address.
    /// 5. Initialize the logic contract: It makes a `delegatecall` to the `initialize` function of the
    /// `SMARTComplianceImplementation` contract.
    ///    This `initialize` call sets up the initial state of the logic contract *within the context of the proxy's
    /// storage*.
    ///    If this initialization `delegatecall` fails, the constructor reverts.
    /// @param systemAddress The address of the `ISMARTSystem` contract. This system contract is responsible for
    /// providing the address of the actual compliance logic (implementation) contract.
    constructor(address systemAddress) {
        // Validate that the provided systemAddress is a valid contract implementing ISMARTSystem
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.complianceImplementation();

        // Ensure the ISMARTSystem contract has a compliance implementation configured.
        if (implementation == address(0)) revert ComplianceImplementationNotSet();

        // Prepare the data for the delegatecall to the implementation's initialize function.
        // This calls SMARTComplianceImplementation.initialize().
        bytes memory data = abi.encodeWithSelector(SMARTComplianceImplementation.initialize.selector);

        // Perform the delegatecall to initialize the implementation contract in the context of this proxy's storage.
        // slither-disable-next-line low-level-calls: Delegatecall is inherent to proxy functionality.
        (bool success,) = implementation.delegatecall(data);

        // If the initialization call failed, revert the proxy deployment.
        if (!success) revert InitializationFailed();
    }

    /// @notice Determines the address of the current logic/implementation contract.
    /// @dev This function is a core part of OpenZeppelin's `Proxy` contract machinery (specifically for EIP-1967).
    /// It is called internally by the `Proxy` contract before every external function call made to this proxy.
    /// The `Proxy` then uses this returned address to `delegatecall` the user's request to the correct logic contract.
    /// In this specific proxy, the implementation address is dynamically fetched from the `ISMARTSystem` contract.
    /// This allows the `ISMARTSystem` admin to upgrade the compliance logic system-wide by updating the address it
    /// returns.
    /// @return implementationAddress The current address of the `SMARTComplianceImplementation` contract that this
    /// proxy should delegate calls to.
    function _implementation() internal view override returns (address implementationAddress) {
        ISMARTSystem system_ = _getSystem();
        implementationAddress = system_.complianceImplementation();
    }

    /// @notice Rejects any direct Ether transfers to this proxy contract.
    /// @dev Proxy contracts typically should not hold Ether themselves unless specifically designed for it.
    /// The `payable` keyword makes the function able to receive Ether, but the `revert` statement ensures any attempts
    /// are rejected.
    /// This helps prevent accidental locking of funds.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
