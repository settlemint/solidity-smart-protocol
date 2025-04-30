// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Adjust import path assuming SMARTInfrastructureSetup will be in ./utils/
import { Test } from "forge-std/Test.sol";
import { ISMART } from "../../contracts/interface/ISMART.sol";
import { ISMARTComplianceModule } from "../../contracts/interface/ISMARTComplianceModule.sol";
import { ISMARTIdentityRegistry } from "../../contracts/interface/ISMARTIdentityRegistry.sol";
import { SMARTIdentityRegistry } from "../../contracts/SMARTIdentityRegistry.sol";
import { TestConstants } from "./Constants.sol";
import { ClaimUtils } from "./utils/ClaimUtils.sol";
import { IdentityUtils } from "./utils/IdentityUtils.sol";
import { TokenUtils } from "./utils/TokenUtils.sol";
import { InfrastructureUtils } from "./utils/InfrastructureUtils.sol";
import { MockedComplianceModule } from "./mocks/MockedComplianceModule.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { CountryAllowListComplianceModule } from "../../contracts/compliance/CountryAllowListComplianceModule.sol";
import { SMARTTest } from "./SMARTTest.sol";

abstract contract SMARTCountryAllowListTest is SMARTTest {
    // Module-specific variables
    CountryAllowListComplianceModule public allowModule;
    uint16[] public countryCodes;

    // Internal setup function, follows pattern of other test classes
    function _setUpCountryAllowList() internal {
        super.setUp();

        // Setup token with default collateral claim
        _setupDefaultCollateralClaim();
        // Don't call _mintInitialBalances() here since we're minting in the test

        // Setup CountryAllowListComplianceModule
        allowModule = infrastructureUtils.countryAllowListComplianceModule();

        // Configure allowed countries (Belgium and Japan)
        countryCodes = new uint16[](2);
        countryCodes[0] = TestConstants.COUNTRY_CODE_BE;
        countryCodes[1] = TestConstants.COUNTRY_CODE_JP;

        // Set allowed countries in the module (globally)
        vm.prank(platformAdmin);
        allowModule.setGlobalAllowedCountries(countryCodes, true);
    }

    // =====================================================================
    //                      COUNTRY COMPLIANCE TESTS
    // =====================================================================

    function test_CountryAllowListCompliance() public {
        // Call setup explicitly
        _setUpCountryAllowList();

        // Add the CountryAllowListComplianceModule to the token
        // Use tokenIssuer since they have COMPLIANCE_ADMIN_ROLE
        vm.prank(tokenIssuer);
        token.addComplianceModule(
            address(allowModule),
            abi.encode(countryCodes) // Pass BE and JP directly in the params
        );

        // Reset balances first to avoid double-minting issues in test suite
        uint256 currentBalBE = token.balanceOf(clientBE);
        uint256 currentBalJP = token.balanceOf(clientJP);
        if (currentBalBE > 0) {
            tokenUtils.burnToken(address(token), tokenIssuer, clientBE, currentBalBE);
        }
        if (currentBalJP > 0) {
            tokenUtils.burnToken(address(token), tokenIssuer, clientJP, currentBalJP);
        }

        // Mint tokens only to allowed countries (BE and JP)
        vm.startPrank(tokenIssuer);
        token.mint(clientBE, INITIAL_MINT_AMOUNT);
        token.mint(clientJP, INITIAL_MINT_AMOUNT);
        vm.stopPrank();

        // Test transfer between allowed countries (BE to JP)
        vm.prank(clientBE);
        token.transfer(clientJP, 10 ether);

        // Test transfer between allowed countries (JP to BE)
        vm.prank(clientJP);
        token.transfer(clientBE, 5 ether);

        // Try to mint to a client from US (not allowed country) - should fail
        vm.startPrank(tokenIssuer);
        vm.expectRevert(); // Should revert as US is not in the allowed countries list
        token.mint(clientUS, INITIAL_MINT_AMOUNT);
        vm.stopPrank();

        // Verify balances to confirm transfers worked as expected
        assertEq(token.balanceOf(clientBE), INITIAL_MINT_AMOUNT - 10 ether + 5 ether, "BE balance incorrect");
        assertEq(token.balanceOf(clientJP), INITIAL_MINT_AMOUNT + 10 ether - 5 ether, "JP balance incorrect");
        assertEq(token.balanceOf(clientUS), 0, "US balance should be zero");
    }
}
