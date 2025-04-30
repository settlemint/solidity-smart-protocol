// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Adjust import path assuming SMARTInfrastructureSetup will be in ./utils/
import { Test } from "forge-std/Test.sol";
import { ISMART } from "../../contracts/interface/ISMART.sol";
import { ISMARTCompliance } from "../../contracts/interface/ISMARTCompliance.sol";
import { ISMARTComplianceModuleParamPair } from "../../contracts/interface/structs/ISMARTComplianceModuleParamPair.sol";
import { ISMARTIdentityRegistry } from "../../contracts/interface/ISMARTIdentityRegistry.sol";
import { SMARTIdentityRegistry } from "../../contracts/SMARTIdentityRegistry.sol";
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
    address public claimIssuer;

    // --- Test Data ---
    uint256[] public requiredClaimTopics;
    uint16[] public allowedCountries;
    ISMARTComplianceModuleParamPair[] public modulePairs;

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

        // --- Initialize Actors ---
        tokenIssuer = makeAddr("Token issuer");
        clientBE = makeAddr("Client BE");
        clientJP = makeAddr("Client JP");
        clientUS = makeAddr("Client US");
        clientUnverified = makeAddr("Client Unverified");
        claimIssuer = vm.addr(claimIssuerPrivateKey);

        // --- Setup utilities
        identityUtils = new IdentityUtils(
            platformAdmin,
            infrastructureUtils.identityFactory(),
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.trustedIssuersRegistry()
        );
        claimUtils = new ClaimUtils(
            platformAdmin,
            claimIssuer,
            claimIssuerPrivateKey,
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.identityFactory()
        );
        tokenUtils = new TokenUtils(
            platformAdmin,
            infrastructureUtils.identityFactory(),
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.compliance()
        );

        // --- Initialize Test Data FIRST ---
        requiredClaimTopics = new uint256[](2);
        requiredClaimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        requiredClaimTopics[1] = TestConstants.CLAIM_TOPIC_AML;

        allowedCountries = new uint16[](2);
        allowedCountries[0] = TestConstants.COUNTRY_CODE_BE;
        allowedCountries[1] = TestConstants.COUNTRY_CODE_JP;

        // --- Setup Identities AFTER requiredClaimTopics is initialized ---
        _setupIdentities();

        modulePairs = new ISMARTComplianceModuleParamPair[](1);
        modulePairs[0] =
            ISMARTComplianceModuleParamPair({ module: address(mockComplianceModule), params: abi.encode("") });

        _setupToken();

        assertNotEq(address(token), address(0), "Token not deployed");
        vm.label(address(token), "Token");

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

    /**
     * @notice Issues a large, long-lived collateral claim to the token's identity.
     * @dev Should be called by inheriting test suites in setUp() *after* _setupToken()
     *      if they require the token to be generally mintable, unless they need
     *      specific collateral scenarios (like SMARTCollateralTest).
     */
    function _setupDefaultCollateralClaim() internal {
        require(address(token) != address(0), "Token must be set up before adding collateral claim");

        // Use a very large amount and a long expiry
        uint256 largeCollateralAmount = type(uint256).max / 2; // Avoid hitting absolute max
        uint256 farFutureExpiry = block.timestamp + 3650 days; // ~10 years

        claimUtils.issueCollateralClaim(address(token), tokenIssuer, largeCollateralAmount, farFutureExpiry);
    }

    function _mintInitialBalances() internal {
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, INITIAL_MINT_AMOUNT);
        tokenUtils.mintToken(address(token), tokenIssuer, clientJP, INITIAL_MINT_AMOUNT);
        tokenUtils.mintToken(address(token), tokenIssuer, clientUS, INITIAL_MINT_AMOUNT);
        // clientUnverified does not get initial balance
        mockComplianceModule.reset(); // Reset count after setup mints
    }

    function _setupIdentities() internal {
        // (Reverted to original logic provided by user)
        // Create the token issuer identixty
        identityUtils.createClientIdentity(tokenIssuer, TestConstants.COUNTRY_CODE_BE);
        // Issue claims to the token issuer as well (assuming they need verification)
        uint256[] memory claimTopics = new uint256[](3);
        claimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        claimTopics[1] = TestConstants.CLAIM_TOPIC_AML;
        claimTopics[2] = TestConstants.CLAIM_TOPIC_COLLATERAL;
        // Use claimIssuer address directly, createIssuerIdentity handles creating the on-chain identity
        vm.label(claimIssuer, "Claim Issuer");
        address claimIssuerIdentity = identityUtils.createIssuerIdentity(claimIssuer, claimTopics);
        vm.label(claimIssuerIdentity, "Claim Issuer Identity");

        // Now issue claims TO the token issuer
        claimUtils.issueAllClaims(tokenIssuer);

        // Create the client identities
        address clientBEIdentity = identityUtils.createClientIdentity(clientBE, TestConstants.COUNTRY_CODE_BE);
        vm.label(clientBEIdentity, "Client BE Identity");
        address clientJPIdentity = identityUtils.createClientIdentity(clientJP, TestConstants.COUNTRY_CODE_JP);
        vm.label(clientJPIdentity, "Client JP Identity");
        address clientUSIdentity = identityUtils.createClientIdentity(clientUS, TestConstants.COUNTRY_CODE_US);
        vm.label(clientUSIdentity, "Client US Identity");
        address clientUnverifiedIdentity =
            identityUtils.createClientIdentity(clientUnverified, TestConstants.COUNTRY_CODE_BE);
        vm.label(clientUnverifiedIdentity, "Client Unverified Identity");

        // Issue claims to clients
        claimUtils.issueAllClaims(clientBE);
        claimUtils.issueAllClaims(clientJP);
        claimUtils.issueAllClaims(clientUS);
        // Only issue KYC claim to the unverified client
        claimUtils.issueKYCClaim(clientUnverified);
    }

    // =====================================================================
    //                      INITIALIZATION & BASIC TESTS
    // =====================================================================

    function test_InitialState() public {
        require(address(token) != address(0), "Token not deployed");
    }
}
