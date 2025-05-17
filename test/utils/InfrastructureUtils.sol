// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { MockedComplianceModule } from "./mocks/MockedComplianceModule.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";

// System
import { SMARTSystemFactory } from "../../contracts/system/SMARTSystemFactory.sol";
import { ISMARTSystem } from "../../contracts/system/ISMARTSystem.sol";

// Implementations
import { SMARTIdentityRegistryStorageImplementation } from
    "../../contracts/system/identity-registry-storage/SMARTIdentityRegistryStorageImplementation.sol";
import { SMARTTrustedIssuersRegistryImplementation } from
    "../../contracts/system/trusted-issuers-registry/SMARTTrustedIssuersRegistryImplementation.sol";
import { SMARTIdentityRegistryImplementation } from
    "../../contracts/system/identity-registry/SMARTIdentityRegistryImplementation.sol";
import { SMARTComplianceImplementation } from "../../contracts/system/compliance/SMARTComplianceImplementation.sol";
import { SMARTIdentityFactoryImplementation } from
    "../../contracts/system/identity-factory/SMARTIdentityFactoryImplementation.sol";

import { SMARTIdentityImplementation } from
    "../../contracts/system/identity-factory/identities/SMARTIdentityImplementation.sol";
import { SMARTTokenIdentityImplementation } from
    "../../contracts/system/identity-factory/identities/SMARTTokenIdentityImplementation.sol";

// Interfaces
import { ISMARTIdentityRegistry } from "../../contracts/interface/ISMARTIdentityRegistry.sol";
import { ISMARTIdentityFactory } from "../../contracts/system/identity-factory/ISMARTIdentityFactory.sol";
import { ISMARTCompliance } from "../../contracts/interface/ISMARTCompliance.sol";
import { IERC3643TrustedIssuersRegistry } from "../../contracts/interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { IERC3643IdentityRegistryStorage } from "../../contracts/interface/ERC-3643/IERC3643IdentityRegistryStorage.sol";

// Compliance Modules
import { CountryAllowListComplianceModule } from
    "../../contracts/system/compliance/modules/CountryAllowListComplianceModule.sol";
import { CountryBlockListComplianceModule } from
    "../../contracts/system/compliance/modules/CountryBlockListComplianceModule.sol";

contract InfrastructureUtils is Test {
    // System
    SMARTSystemFactory public systemFactory;
    ISMARTSystem public system;

    // Core Contract Instances (now holding proxy addresses)
    IERC3643IdentityRegistryStorage public identityRegistryStorage; // Proxy
    IERC3643TrustedIssuersRegistry public trustedIssuersRegistry; // Proxy
    ISMARTIdentityRegistry public identityRegistry; // Proxy
    ISMARTCompliance public compliance; // Proxy
    ISMARTIdentityFactory public identityFactory; // Proxy

    // Compliance Modules
    MockedComplianceModule public mockedComplianceModule;
    CountryAllowListComplianceModule public countryAllowListComplianceModule;
    CountryBlockListComplianceModule public countryBlockListComplianceModule;

    // --- Setup ---
    constructor(address platformAdmin) {
        // --- Predeployed implementations ---
        address forwarder = address(0);

        IIdentity identityImpl = new SMARTIdentityImplementation();
        IIdentity tokenIdentityImpl = new SMARTTokenIdentityImplementation();

        SMARTIdentityRegistryStorageImplementation storageImpl =
            new SMARTIdentityRegistryStorageImplementation(forwarder);
        SMARTTrustedIssuersRegistryImplementation issuersImpl = new SMARTTrustedIssuersRegistryImplementation(forwarder);
        SMARTComplianceImplementation complianceImpl = new SMARTComplianceImplementation(forwarder);
        SMARTIdentityRegistryImplementation registryImpl = new SMARTIdentityRegistryImplementation(forwarder);
        SMARTIdentityFactoryImplementation factoryImpl = new SMARTIdentityFactoryImplementation(forwarder);

        systemFactory = new SMARTSystemFactory(
            address(complianceImpl),
            address(registryImpl),
            address(storageImpl),
            address(issuersImpl),
            address(factoryImpl),
            address(identityImpl),
            address(tokenIdentityImpl),
            forwarder
        );
        vm.label(address(systemFactory), "System Factory");

        vm.startPrank(platformAdmin); // Use admin for initialization and binding
        // --- During onboarding ---
        system = ISMARTSystem(systemFactory.createSystem());
        vm.label(address(system), "System");
        system.bootstrap();

        compliance = ISMARTCompliance(system.complianceProxy());
        vm.label(address(compliance), "Compliance");
        identityRegistry = ISMARTIdentityRegistry(system.identityRegistryProxy());
        vm.label(address(identityRegistry), "Identity Registry");
        identityRegistryStorage = IERC3643IdentityRegistryStorage(system.identityRegistryStorageProxy());
        vm.label(address(identityRegistryStorage), "Identity Registry Storage");
        trustedIssuersRegistry = IERC3643TrustedIssuersRegistry(system.trustedIssuersRegistryProxy());
        vm.label(address(trustedIssuersRegistry), "Trusted Issuers Registry");
        identityFactory = ISMARTIdentityFactory(system.identityFactoryProxy());
        vm.label(address(identityFactory), "Identity Factory");

        // --- Deploy Other Contracts ---
        mockedComplianceModule = new MockedComplianceModule();
        vm.label(address(mockedComplianceModule), "Mocked Compliance Module");
        countryAllowListComplianceModule = new CountryAllowListComplianceModule();
        vm.label(address(countryAllowListComplianceModule), "Country Allow List Compliance Module");
        countryBlockListComplianceModule = new CountryBlockListComplianceModule();
        vm.label(address(countryBlockListComplianceModule), "Country Block List Compliance Module");

        vm.stopPrank();
    }
}
