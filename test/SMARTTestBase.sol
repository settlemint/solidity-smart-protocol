// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Adjust import path assuming SMARTInfrastructureSetup will be in ./utils/
import { Test } from "forge-std/Test.sol";
import { ISMART } from "../contracts/SMART/interface/ISMART.sol";
import { ISMARTComplianceModule } from "../contracts/SMART/interface/ISMARTComplianceModule.sol";
import { _SMARTPausableLogic } from "../contracts/SMART/extensions/base/_SMARTPausableLogic.sol";
import { TestConstants } from "./utils/Constants.sol"; // Assuming Constants.sol exists here
import { ClaimUtils } from "./utils/ClaimUtils.sol"; // Needed for _setupIdentities
import { IdentityUtils } from "./utils/IdentityUtils.sol"; // Needed for _setupIdentities
import { TokenUtils } from "./utils/TokenUtils.sol"; // Needed for tests
import { InfrastructureUtils } from "./utils/InfrastructureUtils.sol"; // Needed for tests
import { MockedComplianceModule } from "./mocks/MockedComplianceModule.sol";

abstract contract SMARTTestBase is Test {
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

        // --- Setup Identities ---
        _setupIdentities();

        requiredClaimTopics = new uint256[](2);
        requiredClaimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        requiredClaimTopics[1] = TestConstants.CLAIM_TOPIC_AML;

        allowedCountries = new uint16[](2);
        allowedCountries[0] = TestConstants.COUNTRY_CODE_BE;
        allowedCountries[1] = TestConstants.COUNTRY_CODE_JP;

        modulePairs = new ISMART.ComplianceModuleParamPair[](1);
        modulePairs[0] =
            ISMART.ComplianceModuleParamPair({ module: address(mockComplianceModule), params: abi.encode("") });
    }

    // --- Test Functions ---
    // These tests now operate on the `token` variable set by inheriting contracts

    function test_Mint() public {
        // Assumes token is deployed and identities are set up by setUp() in inheriting contract
        require(address(token) != address(0), "Token not deployed in setUp");

        // --- Minting --- (Use TokenUtils with the deployed token address)
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 1000);
        assertEq(token.balanceOf(clientBE), 1000, "Initial mint failed");
        assertEq(mockComplianceModule.createdCallCount(), 1, "Mock created hook count incorrect after mint");
    }

    function test_Transfer() public {
        // Assumes token is deployed and identities are set up by setUp() in inheriting contract
        require(address(token) != address(0), "Token not deployed in setUp");

        // --- Initial Mint ---
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 1000);
        assertEq(token.balanceOf(clientBE), 1000, "Setup mint failed");
        assertEq(mockComplianceModule.createdCallCount(), 1, "Mock created hook count incorrect after setup mint");

        // Reset counter for transfer tests
        mockComplianceModule.reset();

        // --- Transfers --- (Use TokenUtils with the deployed token address)

        // Test successful transfer
        uint256 transferredHookCountBefore = mockComplianceModule.transferredCallCount();
        tokenUtils.transferToken(address(token), clientBE, clientJP, 100);
        assertEq(token.balanceOf(clientJP), 100, "Successful transfer failed (receiver balance)");
        assertEq(token.balanceOf(clientBE), 900, "Successful transfer failed (sender balance)");
        assertEq(
            mockComplianceModule.transferredCallCount(),
            transferredHookCountBefore + 1,
            "Mock transferred hook count incorrect after successful transfer"
        );

        // Test blocked transfer (mock)
        mockComplianceModule.setNextTransferShouldFail(true);
        vm.expectRevert(
            abi.encodeWithSelector(ISMARTComplianceModule.ComplianceCheckFailed.selector, "Mocked compliance failure")
        );
        tokenUtils.transferToken(address(token), clientBE, clientUS, 100);
        mockComplianceModule.setNextTransferShouldFail(false);

        assertEq(token.balanceOf(clientUS), 0, "Blocked transfer should have failed (receiver balance)");
        assertEq(token.balanceOf(clientBE), 900, "Blocked transfer should have failed (sender balance)");

        // Test transfer blocked by verification (should not hit mock compliance)
        uint256 transferredHookCountBeforeUnverified = mockComplianceModule.transferredCallCount();
        vm.expectRevert(abi.encodeWithSelector(ISMART.RecipientNotVerified.selector));
        tokenUtils.transferToken(address(token), clientBE, clientUnverified, 100);
        assertEq(
            token.balanceOf(clientUnverified), 0, "Verification-blocked transfer should have failed (receiver balance)"
        );
        assertEq(token.balanceOf(clientBE), 900, "Verification-blocked transfer should have failed (sender balance)");
        assertEq(
            mockComplianceModule.transferredCallCount(),
            transferredHookCountBeforeUnverified,
            "Mock transferred hook count changed on verification fail"
        );
    }

    function test_Pause() public {
        // Assumes token is deployed and identities are set up by setUp() in inheriting contract
        require(address(token) != address(0), "Token not deployed in setUp");

        mockComplianceModule.reset(); // Reset for this test

        uint256 createdHookCountBefore = mockComplianceModule.createdCallCount();
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 500);
        assertEq(
            mockComplianceModule.createdCallCount(),
            createdHookCountBefore + 1,
            "Mock created hook count incorrect after initial mint in test_Pause"
        );

        tokenUtils.pauseToken(address(token), tokenIssuer);

        // Check minting is paused
        vm.expectRevert(abi.encodeWithSelector(_SMARTPausableLogic.TokenPaused.selector));
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 500);

        // Check transfers are paused
        vm.expectRevert(abi.encodeWithSelector(_SMARTPausableLogic.TokenPaused.selector));
        tokenUtils.transferToken(address(token), clientBE, clientJP, 100);

        // Check burning is paused (Add burn function to TokenUtils if needed)
        // vm.expectRevert(abi.encodeWithSelector(_SMARTPausableLogic.TokenPaused.selector));
        // tokenUtils.burnToken(address(token), clientBE, 10);

        // Unpause
        tokenUtils.unpauseToken(address(token), tokenIssuer);

        // Check minting works again
        createdHookCountBefore = mockComplianceModule.createdCallCount();
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 100);
        assertEq(token.balanceOf(clientBE), 600); // 500 initial + 100 new
        assertEq(
            mockComplianceModule.createdCallCount(),
            createdHookCountBefore + 1,
            "Mock created hook count incorrect after mint post-unpause"
        );

        // Check transfer works again
        uint256 transferredHookCountBefore = mockComplianceModule.transferredCallCount();
        tokenUtils.transferToken(address(token), clientBE, clientJP, 50);
        assertEq(token.balanceOf(clientJP), 50);
        assertEq(token.balanceOf(clientBE), 550);
        assertEq(
            mockComplianceModule.transferredCallCount(),
            transferredHookCountBefore + 1,
            "Mock transferred hook count incorrect after transfer post-unpause"
        );
    }

    // --- Internal Helper Functions ---

    function _setupIdentities() internal {
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
}
