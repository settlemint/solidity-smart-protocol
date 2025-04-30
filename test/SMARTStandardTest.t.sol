// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// This file now represents the test suite for the STANDARD token implementation.
// It inherits the common test logic and infrastructure setup.

import { SMARTCoreTest } from "./tests/SMARTCoreTest.sol";
import { SMARTBurnableTest } from "./tests/SMARTBurnableTest.sol";
import { SMARTPausableTest } from "./tests/SMARTPausableTest.sol";
import { SMARTCustodianTest } from "./tests/SMARTCustodianTest.sol";
import { SMARTCollateralTest } from "./tests/SMARTCollateralTest.sol";
import { SMARTCountryAllowListTest } from "./tests/SMARTCountryAllowListTest.sol";
import { ISMART } from "../contracts/interface/ISMART.sol";
// Rename contract to reflect its purpose

contract SMARTStandardTest is
    SMARTCoreTest,
    SMARTBurnableTest,
    SMARTPausableTest,
    SMARTCustodianTest,
    SMARTCollateralTest,
    SMARTCountryAllowListTest
{
    function _setupToken() internal override {
        // Use TokenUtils to create the token, passing the bondFactory from base
        address bondAddress = tokenUtils.createToken(
            "Test Bond",
            "TSTB",
            requiredClaimTopics,
            modulePairs,
            tokenIssuer // Use tokenIssuer address from base
        );

        token = ISMART(bondAddress);
    }
}
