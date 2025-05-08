// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Identity } from "@onchainid/contracts/Identity.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { SMARTIdentityRegistryStorage } from "../../../contracts/SMARTIdentityRegistryStorage.sol";
import { SMARTTrustedIssuersRegistry } from "../../../contracts/SMARTTrustedIssuersRegistry.sol";
import { SMARTIdentityRegistry } from "../../../contracts/SMARTIdentityRegistry.sol";
import { SMARTCompliance } from "../../../contracts/SMARTCompliance.sol";
import { SMARTIdentityFactory } from "../../../contracts/SMARTIdentityFactory.sol";
import { IClaimIssuer } from "@onchainid/contracts/interface/IClaimIssuer.sol";
import { ISMART } from "../../../contracts/interface/ISMART.sol";
import { CountryAllowListComplianceModule } from "../../../contracts/compliance/CountryAllowListComplianceModule.sol";
import { CountryBlockListComplianceModule } from "../../../contracts/compliance/CountryBlockListComplianceModule.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockedComplianceModule } from "../mocks/MockedComplianceModule.sol";
import { ImplementationAuthority } from "@onchainid/contracts/proxy/ImplementationAuthority.sol";

contract InfrastructureUtils is Test {
    // Core Contract Instances (now holding proxy addresses)
    SMARTIdentityRegistryStorage public identityRegistryStorage; // Proxy
    SMARTTrustedIssuersRegistry public trustedIssuersRegistry; // Proxy
    SMARTIdentityRegistry public identityRegistry; // Proxy
    SMARTCompliance public compliance; // Proxy
    SMARTIdentityFactory public identityFactory; // Proxy
    ImplementationAuthority public implementationAuthority;

    // Compliance Modules
    MockedComplianceModule public mockedComplianceModule;
    CountryAllowListComplianceModule public countryAllowListComplianceModule;
    CountryBlockListComplianceModule public countryBlockListComplianceModule;

    // --- Setup ---
    constructor(address platformAdmin) {
        // --- Deploy Implementations ---
        Identity identityImpl = new Identity(address(0), true); // Deploy Identity impl needed by authority
        SMARTIdentityRegistryStorage storageImpl = new SMARTIdentityRegistryStorage(address(0));
        SMARTTrustedIssuersRegistry issuersImpl = new SMARTTrustedIssuersRegistry(address(0));
        SMARTCompliance complianceImpl = new SMARTCompliance(address(0));
        SMARTIdentityFactory factoryImpl = new SMARTIdentityFactory(address(0));
        SMARTIdentityRegistry registryImpl = new SMARTIdentityRegistry(address(0));

        // --- Deploy Proxies and Initialize using Helper ---
        vm.startPrank(platformAdmin); // Use admin for initialization and binding

        // --- Deploy ImplementationAuthority FIRST ---
        implementationAuthority = new ImplementationAuthority(address(identityImpl));

        // Storage Proxy
        bytes memory storageInitData = abi.encodeCall(SMARTIdentityRegistryStorage.initialize, (platformAdmin));
        identityRegistryStorage = SMARTIdentityRegistryStorage(_deployProxy(address(storageImpl), storageInitData));
        vm.label(address(identityRegistryStorage), "Identity Registry Storage");

        // Issuers Proxy
        bytes memory issuersInitData = abi.encodeCall(SMARTTrustedIssuersRegistry.initialize, (platformAdmin));
        trustedIssuersRegistry = SMARTTrustedIssuersRegistry(_deployProxy(address(issuersImpl), issuersInitData));
        vm.label(address(trustedIssuersRegistry), "Trusted Issuers Registry");

        // Compliance Proxy
        bytes memory complianceInitData = abi.encodeCall(SMARTCompliance.initialize, (platformAdmin));
        compliance = SMARTCompliance(_deployProxy(address(complianceImpl), complianceInitData));
        vm.label(address(compliance), "Compliance");
        // Factory Proxy - Pass ImplementationAuthority address
        bytes memory factoryInitData =
            abi.encodeCall(SMARTIdentityFactory.initialize, (platformAdmin, address(implementationAuthority)));
        identityFactory = SMARTIdentityFactory(_deployProxy(address(factoryImpl), factoryInitData));
        vm.label(address(identityFactory), "Identity Factory");

        // Registry Proxy
        bytes memory registryInitData = abi.encodeCall(
            SMARTIdentityRegistry.initialize,
            (platformAdmin, address(identityRegistryStorage), address(trustedIssuersRegistry))
        );
        identityRegistry = SMARTIdentityRegistry(_deployProxy(address(registryImpl), registryInitData));
        vm.label(address(identityRegistry), "Identity Registry");

        // Bind Registry to Storage
        identityRegistryStorage.bindIdentityRegistry(address(identityRegistry));

        // --- Deploy Other Contracts ---
        mockedComplianceModule = new MockedComplianceModule();
        vm.label(address(mockedComplianceModule), "Mocked Compliance Module");
        countryAllowListComplianceModule = new CountryAllowListComplianceModule();
        vm.label(address(countryAllowListComplianceModule), "Country Allow List Compliance Module");
        countryBlockListComplianceModule = new CountryBlockListComplianceModule();
        vm.label(address(countryBlockListComplianceModule), "Country Block List Compliance Module");

        vm.stopPrank();
    }

    // --- Helper Functions ---

    /**
     * @notice Deploys an ERC1967Proxy for a given implementation and initializes it.
     * @param implementation The address of the implementation contract.
     * @param initializeData The abi.encodeCall(...) data for the initialize function.
     * @return proxyAddress The address of the deployed proxy contract.
     */
    function _deployProxy(
        address implementation,
        bytes memory initializeData
    )
        internal
        returns (address proxyAddress)
    {
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initializeData);
        return address(proxy);
    }
}
