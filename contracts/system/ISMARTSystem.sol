// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTSystem {
    function bootstrap(address initialAdmin) external;
    function complianceImplementation() external view returns (address);
    function identityRegistryImplementation() external view returns (address);
    function identityRegistryStorageImplementation() external view returns (address);
    function identityFactoryImplementation() external view returns (address);
    function trustedIssuersRegistryImplementation() external view returns (address);
    function identityImplementation() external view returns (address);
    function tokenIdentityImplementation() external view returns (address);

    function complianceProxy() external view returns (address);
    function identityRegistryProxy() external view returns (address);
    function identityRegistryStorageProxy() external view returns (address);
    function trustedIssuersRegistryProxy() external view returns (address);
    function identityFactoryProxy() external view returns (address);
}
