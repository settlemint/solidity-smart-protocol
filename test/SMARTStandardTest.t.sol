// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// This file now represents the test suite for the STANDARD token implementation.
// It inherits the common test logic and infrastructure setup.

import { SMARTCoreTest } from "./tests/SMARTCoreTest.sol";
import { SMARTBurnableTest } from "./tests/SMARTBurnableTest.sol";
import { SMARTPausableTest } from "./tests/SMARTPausableTest.sol";
import { SMARTCustodianTest } from "./tests/SMARTCustodianTest.sol";
import { SMARTCollateralTest } from "./tests/SMARTCollateralTest.sol";
import { SMARTCountryAllowListTest } from "./tests/SMARTCountryAllowListTest.sol";
import { SMARTCountryBlockListTest } from "./tests/SMARTCountryBlockListTest.sol";
import { ISMART } from "../contracts/interface/ISMART.sol";
import { SMARTToken } from "../contracts/SMARTToken.sol";
import { TestConstants } from "./Constants.sol";
// Rename contract to reflect its purpose

contract SMARTStandardTest is
    SMARTCoreTest,
    SMARTBurnableTest,
    SMARTPausableTest,
    SMARTCustodianTest,
    SMARTCollateralTest,
    SMARTCountryAllowListTest,
    SMARTCountryBlockListTest
{
    function _setupToken() internal override {
        // 1. Create the token contract
        vm.startPrank(tokenIssuer);
        SMARTToken bond = new SMARTToken(
            "Test Bond",
            "TSTB",
            18,
            address(0),
            address(systemUtils.identityRegistry()),
            address(systemUtils.compliance()),
            requiredClaimTopics,
            modulePairs,
            TestConstants.CLAIM_TOPIC_COLLATERAL,
            address(accessManager)
        );
        address tokenAddress = address(bond);
        vm.stopPrank();

        _grantAllRoles(tokenAddress, tokenIssuer);

        // TODO createTokenIdentity --> needs AccessManager

        // 2. Create the token's on-chain identity
        tokenUtils.createAndSetTokenOnchainID(tokenAddress, tokenIssuer, address(accessManager));

        token = ISMART(tokenAddress);
    }
}
