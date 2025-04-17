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
import { ISMARTComplianceModule } from "../../contracts/SMART/interface/ISMARTComplianceModule.sol";

// Import utility contracts (paths may need adjustment if they are in a different subdirectory)
import { IdentityUtils } from "./IdentityUtils.sol";
import { ClaimUtils } from "./ClaimUtils.sol";
import { TokenUtils } from "./TokenUtils.sol";

contract SMARTTestBase is Test {
    // --- State Variables ---
    // Addresses
    address public platformAdmin;

    // Private Keys
    uint256 internal claimIssuerPrivateKey = 0x12345;

    // Core Contract Instances
    SMARTIdentityRegistryStorage internal identityRegistryStorage;
    SMARTTrustedIssuersRegistry internal trustedIssuersRegistry;
    SMARTIdentityRegistry internal identityRegistry;
    SMARTCompliance internal compliance;
    SMARTIdentityFactory internal identityFactory;
    CountryAllowListComplianceModule internal countryAllowListComplianceModule;
    CountryBlockListComplianceModule internal countryBlockListComplianceModule;
    MySMARTTokenFactory internal bondFactory;
    MySMARTTokenFactory internal equityFactory;

    // Utility Contract Instances
    IdentityUtils internal identityUtils;
    ClaimUtils internal claimUtils;
    TokenUtils internal tokenUtils;

    // --- Setup ---
    function setUp() public virtual {
        // Initialize Addresses
        platformAdmin = makeAddr("Platform Admin");

        // Deploy Core Contracts
        vm.startPrank(platformAdmin);

        identityRegistryStorage = new SMARTIdentityRegistryStorage();
        trustedIssuersRegistry = new SMARTTrustedIssuersRegistry();
        identityRegistry = new SMARTIdentityRegistry(address(identityRegistryStorage), address(trustedIssuersRegistry));
        identityRegistryStorage.bindIdentityRegistry(address(identityRegistry));

        compliance = new SMARTCompliance();
        identityFactory = new SMARTIdentityFactory();

        countryAllowListComplianceModule = new CountryAllowListComplianceModule();
        countryBlockListComplianceModule = new CountryBlockListComplianceModule();

        bondFactory = new MySMARTTokenFactory(address(identityRegistry), address(compliance));
        equityFactory = new MySMARTTokenFactory(address(identityRegistry), address(compliance));

        vm.stopPrank();

        // Instantiate Utility Contracts
        identityUtils = new IdentityUtils(platformAdmin, identityFactory, identityRegistry, trustedIssuersRegistry);
        claimUtils = new ClaimUtils(platformAdmin, claimIssuerPrivateKey, identityRegistry);
        tokenUtils = new TokenUtils(platformAdmin, identityFactory, compliance);
    }
}
