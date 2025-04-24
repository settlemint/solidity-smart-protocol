// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Adjust import path assuming SMARTInfrastructureSetup will be in ./utils/
import { Test } from "forge-std/Test.sol";
import { ISMART } from "../../contracts/SMART/interface/ISMART.sol";
import { ISMARTComplianceModule } from "../../contracts/SMART/interface/ISMARTComplianceModule.sol";
import { ISMARTIdentityRegistry } from "../../contracts/SMART/interface/ISMARTIdentityRegistry.sol";
import { SMARTIdentityRegistry } from "../../contracts/SMART/SMARTIdentityRegistry.sol";
import { TestConstants } from "./Constants.sol";
import { ClaimUtils } from "./utils/ClaimUtils.sol";
import { IdentityUtils } from "./utils/IdentityUtils.sol";
import { TokenUtils } from "./utils/TokenUtils.sol";
import { InfrastructureUtils } from "./utils/InfrastructureUtils.sol";
import { MockedComplianceModule } from "./mocks/MockedComplianceModule.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

abstract contract SMARTTest is Test {
    // --- State Variables ---
    ISMART internal token; // Token instance to be tested (set in inheriting contracts)
    MockedComplianceModule internal mockComplianceModule;

    // --- Test Actors ---
    address public platformAdmin;
    address public tokenIssuer;
    address public clientBE;
    address public clientJP;
    address public clientUS;
    address public clientUnverified;
    address public claimIssuer; // Wallet address of the claim issuer

    // --- Test Data ---
    uint256[] public requiredClaimTopics;
    uint16[] public allowedCountries;
    ISMART.ComplianceModuleParamPair[] public modulePairs;

    // --- Private Keys ---
    uint256 internal claimIssuerPrivateKey = 0x12345;

    // --- Utils ---
    InfrastructureUtils internal infrastructureUtils;
    IdentityUtils internal identityUtils;
    ClaimUtils internal claimUtils;
    TokenUtils internal tokenUtils;

    // --- Constants ---
    uint256 internal constant INITIAL_MINT_AMOUNT = 1000 ether;

    // --- Setup ---
    function setUp() public virtual {
        // --- Setup platform admin ---
        platformAdmin = makeAddr("Platform Admin");

        // --- Setup infrastructure ---
        infrastructureUtils = new InfrastructureUtils(platformAdmin);
        mockComplianceModule = infrastructureUtils.mockedComplianceModule();

        // --- Setup utilities
        identityUtils = new IdentityUtils(
            platformAdmin,
            infrastructureUtils.identityFactory(),
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.trustedIssuersRegistry()
        );
        claimUtils = new ClaimUtils(platformAdmin, claimIssuerPrivateKey, infrastructureUtils.identityRegistry());
        tokenUtils = new TokenUtils(
            platformAdmin,
            infrastructureUtils.identityFactory(),
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.compliance()
        );

        // --- Initialize Actors ---
        tokenIssuer = makeAddr("Token issuer");
        clientBE = makeAddr("Client BE");
        clientJP = makeAddr("Client JP");
        clientUS = makeAddr("Client US");
        clientUnverified = makeAddr("Client Unverified");
        claimIssuer = vm.addr(claimIssuerPrivateKey); // Private key defined in SMARTInfrastructureSetup

        // --- Initialize Test Data FIRST ---
        requiredClaimTopics = new uint256[](2);
        requiredClaimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        requiredClaimTopics[1] = TestConstants.CLAIM_TOPIC_AML;

        allowedCountries = new uint16[](2);
        allowedCountries[0] = TestConstants.COUNTRY_CODE_BE;
        allowedCountries[1] = TestConstants.COUNTRY_CODE_JP;

        // --- Setup Identities AFTER requiredClaimTopics is initialized ---
        _setupIdentities();

        modulePairs = new ISMART.ComplianceModuleParamPair[](1);
        modulePairs[0] =
            ISMART.ComplianceModuleParamPair({ module: address(mockComplianceModule), params: abi.encode("") });

        _setupToken();
        assertNotEq(address(token), address(0), "Token not deployed");

        // Grant REGISTRAR_ROLE to the token contract on the Identity Registry
        // Needed for custody address recovery
        address registryAddress = address(infrastructureUtils.identityRegistry());
        address tokenAddress = address(token);

        vm.prank(platformAdmin);
        SMARTIdentityRegistry(payable(registryAddress)).grantRole(TestConstants.REGISTRAR_ROLE, tokenAddress); // Use
            // variable

        // Verify the role was granted
        assertTrue(
            SMARTIdentityRegistry(payable(registryAddress)).hasRole(TestConstants.REGISTRAR_ROLE, tokenAddress), // Use
                // variable
            "Token was not granted REGISTRAR_ROLE"
        );
    }

    function _setupToken() internal virtual { }

    // --- Helper Functions ---
    function _mintInitialBalances() internal {
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, INITIAL_MINT_AMOUNT);
        tokenUtils.mintToken(address(token), tokenIssuer, clientJP, INITIAL_MINT_AMOUNT);
        tokenUtils.mintToken(address(token), tokenIssuer, clientUS, INITIAL_MINT_AMOUNT);
        // clientUnverified does not get initial balance
        mockComplianceModule.reset(); // Reset count after setup mints
    }

    function _setupIdentities() internal {
        // (Reverted to original logic provided by user)
        // Create the token issuer identity
        identityUtils.createClientIdentity(tokenIssuer, TestConstants.COUNTRY_CODE_BE);
        // Issue claims to the token issuer as well (assuming they need verification)
        uint256[] memory claimTopics = new uint256[](2);
        claimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        claimTopics[1] = TestConstants.CLAIM_TOPIC_AML;
        // Use claimIssuer address directly, createIssuerIdentity handles creating the on-chain identity
        address claimIssuerIdentityAddress = identityUtils.createIssuerIdentity(claimIssuer, claimTopics);
        // Now issue claims TO the token issuer
        claimUtils.issueAllClaims(claimIssuerIdentityAddress, tokenIssuer);

        // Create the client identities
        identityUtils.createClientIdentity(clientBE, TestConstants.COUNTRY_CODE_BE);
        identityUtils.createClientIdentity(clientJP, TestConstants.COUNTRY_CODE_JP);
        identityUtils.createClientIdentity(clientUS, TestConstants.COUNTRY_CODE_US);
        identityUtils.createClientIdentity(clientUnverified, TestConstants.COUNTRY_CODE_BE);

        // Issue claims to clients
        claimUtils.issueAllClaims(claimIssuerIdentityAddress, clientBE);
        claimUtils.issueAllClaims(claimIssuerIdentityAddress, clientJP);
        claimUtils.issueAllClaims(claimIssuerIdentityAddress, clientUS);
        // Only issue KYC claim to the unverified client
        claimUtils.issueKYCClaim(claimIssuerIdentityAddress, clientUnverified);
    }

    // =====================================================================
    //                      INITIALIZATION & BASIC TESTS
    // =====================================================================

    function test_InitialState() public {
        require(address(token) != address(0), "Token not deployed");
    }
}
