// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title ISMARTSystem Interface
/// @notice Defines the core functions for the SMART Protocol system,
/// including access to module implementations and their proxies.
interface ISMARTSystem {
    /// @notice Bootstraps the SMART Protocol system, setting up initial configurations and deploying necessary
    /// contracts.
    /// @dev This function should typically be called only once during the initial deployment.
    function bootstrap() external;

    /// @notice Creates a new token registry implementation and proxy.
    /// @param _typeName The human-readable type name of the token registry.
    /// @param _implementation The address of the token registry implementation contract.
    function createTokenRegistry(string calldata _typeName, address _implementation) external;

    /// @notice Returns the address of the current compliance module implementation.
    /// @return The address of the compliance implementation contract.
    function complianceImplementation() external view returns (address);

    /// @notice Returns the address of the current identity registry module implementation.
    /// @return The address of the identity registry implementation contract.
    function identityRegistryImplementation() external view returns (address);

    /// @notice Returns the address of the current identity registry storage module implementation.
    /// @return The address of the identity registry storage implementation contract.
    function identityRegistryStorageImplementation() external view returns (address);

    /// @notice Returns the address of the current identity factory module implementation.
    /// @return The address of the identity factory implementation contract.
    function identityFactoryImplementation() external view returns (address);

    /// @notice Returns the address of the current trusted issuers registry module implementation.
    /// @return The address of the trusted issuers registry implementation contract.
    function trustedIssuersRegistryImplementation() external view returns (address);

    /// @notice Returns the address of the current standard identity contract implementation.
    /// @return The address of the identity implementation contract.
    function identityImplementation() external view returns (address);

    /// @notice Returns the address of the current token identity contract implementation.
    /// @return The address of the token identity implementation contract.
    function tokenIdentityImplementation() external view returns (address);

    /// @notice Returns the address of the current token registry implementation.
    /// @param registryTypeHash The hash of the registry type.
    /// @return The address of the token registry implementation contract.
    function tokenRegistryImplementation(bytes32 registryTypeHash) external view returns (address);

    /// @notice Returns the address of the compliance module proxy.
    /// @return The address of the compliance proxy contract.
    function complianceProxy() external view returns (address);

    /// @notice Returns the address of the identity registry module proxy.
    /// @return The address of the identity registry proxy contract.
    function identityRegistryProxy() external view returns (address);

    /// @notice Returns the address of the identity registry storage module proxy.
    /// @return The address of the identity registry storage proxy contract.
    function identityRegistryStorageProxy() external view returns (address);

    /// @notice Returns the address of the trusted issuers registry module proxy.
    /// @return The address of the trusted issuers registry proxy contract.
    function trustedIssuersRegistryProxy() external view returns (address);

    /// @notice Returns the address of the identity factory module proxy.
    /// @return The address of the identity factory proxy contract.
    function identityFactoryProxy() external view returns (address);

    /// @notice Returns the address of the token registry proxy.
    /// @param registryTypeHash The hash of the registry type.
    /// @return The address of the token registry proxy contract.
    function tokenRegistryProxy(bytes32 registryTypeHash) external view returns (address);
}
