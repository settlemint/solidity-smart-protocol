// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTSystem {
    function complianceImplementation() external view returns (address);
    function identityRegistryImplementation() external view returns (address);
    function identityRegistryStorageImplementation() external view returns (address);
    function identityFactoryImplementation() external view returns (address);
    function trustedIssuersRegistryImplementation() external view returns (address);
    function identityImplementation() external view returns (address);
    function tokenIdentityImplementation() external view returns (address);
}
