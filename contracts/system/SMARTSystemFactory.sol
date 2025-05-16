// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { SMARTSystem } from "./SMARTSystem.sol";
import {
    ComplianceImplementationNotSet,
    IdentityRegistryImplementationNotSet,
    IdentityRegistryStorageImplementationNotSet,
    TrustedIssuersRegistryImplementationNotSet,
    IdentityFactoryImplementationNotSet,
    IdentityImplementationNotSet,
    TokenIdentityImplementationNotSet,
    IndexOutOfBounds
} from "./SMARTSystemErrors.sol";
import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

// --- Contract Definition ---

/// @title SMARTSystemFactory
/// @notice A factory contract for deploying instances of the SMARTSystem.
/// @dev Utilizes default implementation addresses for various SMART modules and supports meta-transactions via
/// ERC2771Context.
contract SMARTSystemFactory is ERC2771Context {
    // --- State Variables ---

    /// @notice The default implementation address for the compliance module.
    address public immutable defaultComplianceImplementation;
    /// @notice The default implementation address for the identity registry module.
    address public immutable defaultIdentityRegistryImplementation;
    /// @notice The default implementation address for the identity registry storage module.
    address public immutable defaultIdentityRegistryStorageImplementation;
    /// @notice The default implementation address for the trusted issuers registry module.
    address public immutable defaultTrustedIssuersRegistryImplementation;
    /// @notice The default implementation address for the identity factory module.
    address public immutable defaultIdentityFactoryImplementation;
    /// @notice The default implementation address for the identity module.
    address public immutable defaultIdentityImplementation;
    /// @notice The default implementation address for the token identity module.
    address public immutable defaultTokenIdentityImplementation;
    /// @notice The address of the trusted forwarder used by this factory and passed to new SMARTSystem instances.
    address public immutable factoryForwarder;

    /// @notice An array storing the addresses of all SMARTSystem instances created by this factory.
    address[] public smartSystems;

    // --- Events ---

    /// @notice Emitted when a new SMARTSystem instance is successfully created.
    /// @param systemAddress The address of the newly deployed SMARTSystem contract.
    /// @param initialAdmin The address set as the initial admin (DEFAULT_ADMIN_ROLE) for the new SMARTSystem.
    event SMARTSystemCreated(address indexed systemAddress, address indexed initialAdmin);

    // --- Constructor ---

    /// @notice Constructs the SMARTSystemFactory.
    /// @dev Initializes default implementation addresses for all SMART modules and the trusted forwarder.
    /// @dev Reverts if any of the provided implementation addresses are the zero address.
    /// @param complianceImplementation_ The default address for the compliance module implementation.
    /// @param identityRegistryImplementation_ The default address for the identity registry module implementation.
    /// @param identityRegistryStorageImplementation_ The default address for the identity registry storage module
    /// implementation.
    /// @param trustedIssuersRegistryImplementation_ The default address for the trusted issuers registry module
    /// implementation.
    /// @param identityFactoryImplementation_ The default address for the identity factory module implementation.
    /// @param identityImplementation_ The default address for the identity module implementation.
    /// @param tokenIdentityImplementation_ The default address for the token identity module implementation.
    /// @param forwarder_ The address of the trusted forwarder for meta-transactions.
    constructor(
        address complianceImplementation_,
        address identityRegistryImplementation_,
        address identityRegistryStorageImplementation_,
        address trustedIssuersRegistryImplementation_,
        address identityFactoryImplementation_,
        address identityImplementation_,
        address tokenIdentityImplementation_,
        address forwarder_
    )
        ERC2771Context(forwarder_)
    {
        if (complianceImplementation_ == address(0)) revert ComplianceImplementationNotSet();
        if (identityRegistryImplementation_ == address(0)) revert IdentityRegistryImplementationNotSet();
        if (identityRegistryStorageImplementation_ == address(0)) {
            revert IdentityRegistryStorageImplementationNotSet();
        }
        if (trustedIssuersRegistryImplementation_ == address(0)) {
            revert TrustedIssuersRegistryImplementationNotSet();
        }
        if (identityFactoryImplementation_ == address(0)) {
            revert IdentityFactoryImplementationNotSet();
        }
        if (identityImplementation_ == address(0)) {
            revert IdentityImplementationNotSet(); // Assumes this error is in SMARTSystemErrors.sol
        }
        if (tokenIdentityImplementation_ == address(0)) {
            revert TokenIdentityImplementationNotSet(); // Assumes this error is in SMARTSystemErrors.sol
        }

        defaultComplianceImplementation = complianceImplementation_;
        defaultIdentityRegistryImplementation = identityRegistryImplementation_;
        defaultIdentityRegistryStorageImplementation = identityRegistryStorageImplementation_;
        defaultTrustedIssuersRegistryImplementation = trustedIssuersRegistryImplementation_;
        defaultIdentityFactoryImplementation = identityFactoryImplementation_;
        defaultIdentityImplementation = identityImplementation_;
        defaultTokenIdentityImplementation = tokenIdentityImplementation_;
        factoryForwarder = forwarder_;
    }

    // --- Public Functions ---

    /// @notice Creates a new SMARTSystem instance using the factory's default implementation addresses.
    /// @dev The caller of this function (msg.sender, or the original signer in a meta-transaction) will be set as the
    /// initial admin of the new SMARTSystem.
    /// @return systemAddress The address of the newly created SMARTSystem contract.
    function createSystem() public returns (address systemAddress) {
        address initialAdmin = _msgSender();

        SMARTSystem newSystem = new SMARTSystem(
            initialAdmin,
            defaultComplianceImplementation,
            defaultIdentityRegistryImplementation,
            defaultIdentityRegistryStorageImplementation,
            defaultTrustedIssuersRegistryImplementation,
            defaultIdentityFactoryImplementation,
            defaultIdentityImplementation,
            defaultTokenIdentityImplementation,
            factoryForwarder
        );

        systemAddress = address(newSystem);
        smartSystems.push(systemAddress);

        emit SMARTSystemCreated(systemAddress, initialAdmin);

        return systemAddress;
    }

    /// @notice Gets the total number of SMARTSystem instances created by this factory.
    /// @return uint256 The count of created SMARTSystem instances.
    function getSystemCount() public view returns (uint256) {
        return smartSystems.length;
    }

    /// @notice Gets the address of a SMARTSystem instance at a specific index in the list of created systems.
    /// @dev Reverts if the index is out of bounds.
    /// @param index The index of the desired SMARTSystem in the `smartSystems` array.
    /// @return address The address of the SMARTSystem contract at the given index.
    function getSystemAtIndex(uint256 index) public view returns (address) {
        if (index >= smartSystems.length) revert IndexOutOfBounds(index, smartSystems.length);
        return smartSystems[index];
    }
}
