// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import "./SMARTSystem.sol";
import "./SMARTSystemErrors.sol";
import { ERC2771Context, Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract SMARTSystemFactory is ERC2771Context {
    // Default implementation addresses and forwarder
    address public defaultComplianceImplementation;
    address public defaultIdentityRegistryImplementation;
    address public defaultIdentityRegistryStorageImplementation;
    address public defaultTrustedIssuersRegistryImplementation;
    address public defaultIdentityFactoryImplementation;
    // defaultForwarder is now managed by ERC2771Context, but we still need it for SMARTSystem constructor
    address public immutable factoryForwarder;

    // Array to store addresses of created SMARTSystem instances
    address[] public smartSystems;

    // Event emitted when a new SMARTSystem is created
    event SMARTSystemCreated(address indexed systemAddress, address indexed initialAdmin);

    constructor(
        address complianceImplementation_,
        address identityRegistryImplementation_,
        address identityRegistryStorageImplementation_,
        address trustedIssuersRegistryImplementation_,
        address identityFactoryImplementation_,
        address forwarder_
    )
        ERC2771Context(forwarder_)
    {
        if (complianceImplementation_ == address(0)) revert ZeroAddressComplianceImplementation();
        if (identityRegistryImplementation_ == address(0)) revert ZeroAddressIdentityRegistryImplementation();
        if (identityRegistryStorageImplementation_ == address(0)) {
            revert ZeroAddressIdentityRegistryStorageImplementation();
        }
        if (trustedIssuersRegistryImplementation_ == address(0)) {
            revert ZeroAddressTrustedIssuersRegistryImplementation();
        }
        if (identityFactoryImplementation_ == address(0)) revert ZeroAddressIdentityFactoryImplementation();

        defaultComplianceImplementation = complianceImplementation_;
        defaultIdentityRegistryImplementation = identityRegistryImplementation_;
        defaultIdentityRegistryStorageImplementation = identityRegistryStorageImplementation_;
        defaultTrustedIssuersRegistryImplementation = trustedIssuersRegistryImplementation_;
        defaultIdentityFactoryImplementation = identityFactoryImplementation_;
        factoryForwarder = forwarder_;
    }

    /**
     * @notice Creates a new SMARTSystem instance, setting _msgSender() as the initial admin.
     * @return systemAddress The address of the newly created SMARTSystem.
     */
    function createSystem() public returns (address systemAddress) {
        address currentMsgSender = _msgSender();

        SMARTSystem newSystem = new SMARTSystem(
            currentMsgSender,
            defaultComplianceImplementation,
            defaultIdentityRegistryImplementation,
            defaultIdentityRegistryStorageImplementation,
            defaultTrustedIssuersRegistryImplementation,
            defaultIdentityFactoryImplementation,
            factoryForwarder
        );

        systemAddress = address(newSystem);
        smartSystems.push(systemAddress);

        emit SMARTSystemCreated(systemAddress, currentMsgSender);

        return systemAddress;
    }

    /**
     * @notice Gets the total number of SMARTSystem instances created by this factory.
     * @return The count of created systems.
     */
    function getSystemCount() public view returns (uint256) {
        return smartSystems.length;
    }

    /**
     * @notice Gets the address of a SMARTSystem instance at a specific index.
     * @param index The index of the system in the internal list.
     * @return The address of the SMARTSystem at the given index.
     */
    function getSystemAtIndex(uint256 index) public view returns (address) {
        if (index >= smartSystems.length) revert IndexOutOfBounds(index, smartSystems.length);
        return smartSystems[index];
    }

    // --- ERC2771Context Overrides ---

    /// @notice Returns the message sender in the context of meta-transactions
    /// @dev Overrides both Context and ERC2771Context to support meta-transactions
    /// @return The address of the message sender
    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return super._msgSender();
    }

    /// @notice Returns the message data in the context of meta-transactions
    /// @dev Overrides both Context and ERC2771Context to support meta-transactions
    /// @return The message data
    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return super._msgData();
    }

    /// @notice Returns the length of the context suffix for meta-transactions
    /// @dev Overrides both Context and ERC2771Context to support meta-transactions
    /// @return The length of the context suffix
    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return super._contextSuffixLength();
    }
}
