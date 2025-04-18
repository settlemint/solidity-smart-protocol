// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Inherit from the base class which sets up contracts and utilities
import { SMARTTestBase } from "./utils/SMARTTestBase.sol";
// Import necessary interfaces/contracts if needed for specific test logic (e.g., for reverts)
import { ISMART } from "../contracts/SMART/interface/ISMART.sol";
import { ISMARTComplianceModule } from "../contracts/SMART/interface/ISMARTComplianceModule.sol";
import { ClaimUtils } from "./utils/ClaimUtils.sol";
import { TestConstants } from "./utils/Constants.sol"; // Import the constants library
import { _SMARTPausableLogic } from "../contracts/SMART/extensions/base/_SMARTPausableLogic.sol";

contract SMARTTest is SMARTTestBase {
    address public tokenIssuer;
    address public clientBE;
    address public clientJP;
    address public clientUS;
    address public clientUnverified;
    address public claimIssuer; // Wallet address of the claim issuer

    function setUp() public override {
        super.setUp();

        tokenIssuer = makeAddr("Token issuer");
        clientBE = makeAddr("Client BE");
        clientJP = makeAddr("Client JP");
        clientUS = makeAddr("Client US");
        clientUnverified = makeAddr("Client Unverified");
        claimIssuer = vm.addr(claimIssuerPrivateKey);
    }

    function _setupIdentities() internal {
        // Create the token issuer identity
        // Note: The original test created a *client* identity for the token issuer.
        // Assuming the token issuer also needs KYC/AML based on typical flows, let's keep this pattern.
        identityUtils.createClientIdentity(tokenIssuer, TestConstants.COUNTRY_CODE_BE);
        // Issue claims to the token issuer as well (assuming they need verification)
        // First, create the claim issuer's identity if not already implicitly handled
        // Create the issuer identity
        uint256[] memory claimTopics = new uint256[](2);
        claimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        claimTopics[1] = TestConstants.CLAIM_TOPIC_AML;
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

    function _createBondToken() internal returns (address) {
        uint256[] memory requiredClaimTopics = new uint256[](2);
        requiredClaimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        requiredClaimTopics[1] = TestConstants.CLAIM_TOPIC_AML;

        uint16[] memory allowedCountries = new uint16[](2);
        allowedCountries[0] = TestConstants.COUNTRY_CODE_BE;
        allowedCountries[1] = TestConstants.COUNTRY_CODE_JP;

        ISMART.ComplianceModuleParamPair[] memory modulePairs = new ISMART.ComplianceModuleParamPair[](1);
        modulePairs[0] = ISMART.ComplianceModuleParamPair({
            module: address(countryAllowListComplianceModule), // Access compliance module from base
            params: abi.encode(allowedCountries)
        });

        // Use TokenUtils to create the token, passing the bondFactory from base
        address bondAddress = tokenUtils.createToken(
            bondFactory, // Use bondFactory instance from base
            "Test Bond",
            "TSTB",
            requiredClaimTopics,
            modulePairs,
            tokenIssuer // Use tokenIssuer address from base
        );

        return bondAddress;
    }

    function test_Mint() public {
        _setupIdentities();
        address bondAddress = _createBondToken();

        // --- Minting --- (Use TokenUtils)
        tokenUtils.mintToken(bondAddress, tokenIssuer, clientBE, 1000);
        assertEq(tokenUtils.getBalance(bondAddress, clientBE), 1000, "Initial mint failed");

        // --- Transfers --- (Use TokenUtils)

        // Transfer BE -> JP (Allowed)
        tokenUtils.transferToken(bondAddress, clientBE, clientJP, 100);
        assertEq(tokenUtils.getBalance(bondAddress, clientJP), 100, "Transfer BE->JP failed (JP balance)");
        assertEq(tokenUtils.getBalance(bondAddress, clientBE), 900, "Transfer BE->JP failed (BE balance)");

        // Transfer BE -> US (Blocked by CountryAllowList)
        vm.expectRevert(
            abi.encodeWithSelector(
                ISMARTComplianceModule.ComplianceCheckFailed.selector, "Receiver country not allowed"
            )
        );
        tokenUtils.transferToken(bondAddress, clientBE, clientUS, 100);
        assertEq(tokenUtils.getBalance(bondAddress, clientUS), 0, "Transfer BE->US should have failed (US balance)");
        assertEq(tokenUtils.getBalance(bondAddress, clientBE), 900, "Transfer BE->US should have failed (BE balance)");

        // Transfer BE -> Unverified (Blocked by missing AML claim)
        vm.expectRevert(abi.encodeWithSelector(ISMART.RecipientNotVerified.selector));
        tokenUtils.transferToken(bondAddress, clientBE, clientUnverified, 100);
        assertEq(
            tokenUtils.getBalance(bondAddress, clientUnverified),
            0,
            "Transfer BE->Unverified should have failed (Unverified balance)"
        );
        assertEq(
            tokenUtils.getBalance(bondAddress, clientBE), 900, "Transfer BE->Unverified should have failed (BE balance)"
        );
    }

    function test_Pause() public {
        _setupIdentities();
        address bondAddress = _createBondToken();

        tokenUtils.mintToken(bondAddress, tokenIssuer, clientBE, 500);

        tokenUtils.pauseToken(bondAddress, tokenIssuer);

        vm.expectRevert(abi.encodeWithSelector(_SMARTPausableLogic.TokenPaused.selector));
        tokenUtils.mintToken(bondAddress, tokenIssuer, clientBE, 500);
    }

    // Add other test functions here, calling helpers via identityUtils, claimUtils, tokenUtils
}
