// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// This file now represents the test suite for the STANDARD token implementation.
// It inherits the common test logic and infrastructure setup.

import { SMARTBaseTest } from "./tests/SMARTBaseTest.sol";
import { SMARTTokenTest } from "./tests/SMARTTokenTest.sol";
import { SMARTBurnableTest } from "./tests/SMARTBurnableTest.sol";
import { SMARTPausableTest } from "./tests/SMARTPausableTest.sol";
import { SMARTCustodianTest } from "./tests/SMARTCustodianTest.sol";
import { ISMART } from "../contracts/SMART/interface/ISMART.sol";
// Rename contract to reflect its purpose

contract SMARTStandardTest is
    SMARTBaseTest,
    SMARTTokenTest,
    SMARTBurnableTest,
    SMARTPausableTest,
    SMARTCustodianTest
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
