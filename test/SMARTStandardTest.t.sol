// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// This file now represents the test suite for the STANDARD token implementation.
// It inherits the common test logic and infrastructure setup.

import { SMARTCoreTest } from "./extensions/SMARTCoreTest.sol";
import { SMARTBurnableTest } from "./extensions/SMARTBurnableTest.sol";
import { SMARTPausableTest } from "./extensions/SMARTPausableTest.sol";
import { SMARTCustodianTest } from "./extensions/SMARTCustodianTest.sol";
import { SMARTCollateralTest } from "./extensions/SMARTCollateralTest.sol";
import { SMARTCountryAllowListTest } from "./extensions/SMARTCountryAllowListTest.sol";
import { SMARTCountryBlockListTest } from "./extensions/SMARTCountryBlockListTest.sol";
import { ISMART } from "../contracts/interface/ISMART.sol";
import { SMARTToken } from "./examples/SMARTToken.sol";
import { SMARTTopics } from "../contracts/system/SMARTTopics.sol";
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
            systemUtils.topicSchemeRegistry().getTopicId(SMARTTopics.TOPIC_COLLATERAL),
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
