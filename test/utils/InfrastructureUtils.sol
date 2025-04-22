// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { MySMARTTokenFactory } from "../../contracts/MySMARTTokenFactory.sol";
import { MySMARTToken } from "../../contracts/MySMARTToken.sol";
import { Identity } from "../../contracts/onchainid/Identity.sol";
import { IIdentity } from "../../contracts/onchainid/interface/IIdentity.sol";
import { SMARTIdentityRegistryStorage } from "../../contracts/SMART/SMARTIdentityRegistryStorage.sol";
import { SMARTTrustedIssuersRegistry } from "../../contracts/SMART/SMARTTrustedIssuersRegistry.sol";
import { SMARTIdentityRegistry } from "../../contracts/SMART/SMARTIdentityRegistry.sol";
import { SMARTCompliance } from "../../contracts/SMART/SMARTCompliance.sol";
import { SMARTIdentityFactory } from "../../contracts/SMART/SMARTIdentityFactory.sol";
import { IClaimIssuer } from "../../contracts/onchainid/interface/IClaimIssuer.sol";
import { ISMART } from "../../contracts/SMART/interface/ISMART.sol";
import { CountryAllowListComplianceModule } from "../../contracts/SMART/compliance/CountryAllowListComplianceModule.sol";
import { CountryBlockListComplianceModule } from "../../contracts/SMART/compliance/CountryBlockListComplianceModule.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockedComplianceModule } from "../mocks/MockedComplianceModule.sol";
import { ImplementationAuthority } from "../../contracts/onchainid/proxy/ImplementationAuthority.sol";

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
        SMARTIdentityRegistryStorage storageImpl = new SMARTIdentityRegistryStorage();
        SMARTTrustedIssuersRegistry issuersImpl = new SMARTTrustedIssuersRegistry();
        SMARTCompliance complianceImpl = new SMARTCompliance();
        SMARTIdentityFactory factoryImpl = new SMARTIdentityFactory();
        SMARTIdentityRegistry registryImpl = new SMARTIdentityRegistry();

        // --- Deploy Proxies and Initialize using Helper ---
        vm.startPrank(platformAdmin); // Use admin for initialization and binding

        // --- Deploy ImplementationAuthority FIRST ---
        implementationAuthority = new ImplementationAuthority(address(identityImpl));

        // Storage Proxy
        bytes memory storageInitData = abi.encodeCall(SMARTIdentityRegistryStorage.initialize, (platformAdmin));
        identityRegistryStorage = SMARTIdentityRegistryStorage(_deployProxy(address(storageImpl), storageInitData));

        // Issuers Proxy
        bytes memory issuersInitData = abi.encodeCall(SMARTTrustedIssuersRegistry.initialize, (platformAdmin));
        trustedIssuersRegistry = SMARTTrustedIssuersRegistry(_deployProxy(address(issuersImpl), issuersInitData));

        // Compliance Proxy
        bytes memory complianceInitData = abi.encodeCall(SMARTCompliance.initialize, (platformAdmin));
        compliance = SMARTCompliance(_deployProxy(address(complianceImpl), complianceInitData));

        // Factory Proxy - Pass ImplementationAuthority address
        bytes memory factoryInitData =
            abi.encodeCall(SMARTIdentityFactory.initialize, (platformAdmin, address(implementationAuthority)));
        identityFactory = SMARTIdentityFactory(_deployProxy(address(factoryImpl), factoryInitData));

        // Registry Proxy
        bytes memory registryInitData = abi.encodeCall(
            SMARTIdentityRegistry.initialize,
            (platformAdmin, address(identityRegistryStorage), address(trustedIssuersRegistry))
        );
        identityRegistry = SMARTIdentityRegistry(_deployProxy(address(registryImpl), registryInitData));

        // Bind Registry to Storage
        identityRegistryStorage.bindIdentityRegistry(address(identityRegistry));

        // --- Deploy Other Contracts ---
        mockedComplianceModule = new MockedComplianceModule();
        countryAllowListComplianceModule = new CountryAllowListComplianceModule();
        countryBlockListComplianceModule = new CountryBlockListComplianceModule();

        vm.stopPrank();

        // --- Instantiate Utility Contracts ---
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
