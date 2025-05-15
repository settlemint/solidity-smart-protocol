// SPDX-License-Identifier: FSL-1.1-MIT

pragma solidity ^0.8.28;

error InitializationFailed();
error ComplianceImplementationNotSet();
error IdentityRegistryImplementationNotSet();
error IdentityRegistryStorageImplementationNotSet();
error TrustedIssuersRegistryImplementationNotSet();
error IdentityFactoryImplementationNotSet();

// Errors for SMARTSystemFactory
error ZeroAddressComplianceImplementation();
error ZeroAddressIdentityRegistryImplementation();
error ZeroAddressIdentityRegistryStorageImplementation();
error ZeroAddressTrustedIssuersRegistryImplementation();
error ZeroAddressIdentityFactoryImplementation();
error ZeroAddressForwarder();
error IndexOutOfBounds(uint256 index, uint256 length);
