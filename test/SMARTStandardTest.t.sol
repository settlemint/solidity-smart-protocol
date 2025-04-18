// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// This file now represents the test suite for the STANDARD token implementation.
// It inherits the common test logic and infrastructure setup.

import { SMARTTestBase } from "./SMARTTestBase.sol"; // Inherit from the logic base
import { ISMART } from "../contracts/SMART/interface/ISMART.sol";
import { TestConstants } from "./utils/Constants.sol";
import { ISMARTComplianceModule } from "../contracts/SMART/interface/ISMARTComplianceModule.sol"; // Keep if needed by
    // _createBondToken

// Rename contract to reflect its purpose
contract SMARTStandardTest is SMARTTestBase {
    function setUp() public override {
        // 1. Call the base setup (infrastructure, actors, identities)
        super.setUp();

        // 2. Deploy the specific (standard) token instance for this test suite
        address tokenAddress = _createToken();

        // 3. Assign the deployed token to the `token` variable in the base contract
        // This allows the tests in SMARTTestLogicBase to run against the standard token.
        token = ISMART(tokenAddress);

        // --- Post-Deployment Setup Specific to Standard Token (if any) ---
        // If _createBondToken doesn't handle everything (e.g., granting roles), do it here.
    }

    // --- Helper Functions Specific to Standard Token ---

    // Keep the function to create the standard token instance
    // Make it private as it's only used within this contract's setup
    function _createToken() private returns (address) {
        uint256[] memory requiredClaimTopics = new uint256[](2);
        requiredClaimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        requiredClaimTopics[1] = TestConstants.CLAIM_TOPIC_AML;

        uint16[] memory allowedCountries = new uint16[](2);
        allowedCountries[0] = TestConstants.COUNTRY_CODE_BE;
        allowedCountries[1] = TestConstants.COUNTRY_CODE_JP;

        ISMART.ComplianceModuleParamPair[] memory modulePairs = new ISMART.ComplianceModuleParamPair[](1);
        modulePairs[0] = ISMART.ComplianceModuleParamPair({
            module: address(infrastructureUtils.countryAllowListComplianceModule()), // Access compliance module from
                // base
            params: abi.encode(allowedCountries)
        });

        // Use TokenUtils to create the token, passing the bondFactory from base
        address bondAddress = tokenUtils.createToken(
            "Test Bond",
            "TSTB",
            requiredClaimTopics,
            modulePairs,
            tokenIssuer // Use tokenIssuer address from base
        );

        return bondAddress;
    }
}
