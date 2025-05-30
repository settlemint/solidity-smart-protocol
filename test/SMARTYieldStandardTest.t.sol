// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { SMARTYieldTest } from "./extensions/SMARTYieldTest.sol";
import { MockERC20 } from "./utils/SMARTYieldHelpers.sol";
import { ISMART } from "../contracts/interface/ISMART.sol";
import { SMARTYieldToken } from "./examples/SMARTYieldToken.sol";
import { SMARTTopics } from "../contracts/system/SMARTTopics.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { SMARTSystemRoles } from "../contracts/system/SMARTSystemRoles.sol";

contract SMARTYieldStandardTest is SMARTYieldTest {
    function _setupToken() internal override {
        // Deploy yield payment token first if not already deployed
        if (yieldPaymentToken == address(0)) {
            yieldPaymentToken = address(new MockERC20("Yield Token", "YIELD"));
        }

        // 1. Create the yield token contract
        vm.startPrank(tokenIssuer);
        SMARTYieldToken yieldToken = new SMARTYieldToken(
            "Test Yield Token",
            "TYIELD",
            18,
            address(0),
            address(systemUtils.identityRegistry()),
            address(systemUtils.compliance()),
            requiredClaimTopics,
            modulePairs,
            systemUtils.topicSchemeRegistry().getTopicId(SMARTTopics.TOPIC_COLLATERAL),
            address(accessManager),
            yieldPaymentToken
        );
        address tokenAddress = address(yieldToken);
        vm.stopPrank();

        // Grant roles using the same pattern as SMARTStandardTest
        vm.startPrank(tokenIssuer);
        // Grant all roles to the token issuer
        IAccessControl(accessManager).grantRole(SMARTYieldToken(tokenAddress).TOKEN_ADMIN_ROLE(), tokenIssuer);
        IAccessControl(accessManager).grantRole(SMARTYieldToken(tokenAddress).COMPLIANCE_ADMIN_ROLE(), tokenIssuer);
        IAccessControl(accessManager).grantRole(SMARTYieldToken(tokenAddress).VERIFICATION_ADMIN_ROLE(), tokenIssuer);
        IAccessControl(accessManager).grantRole(SMARTYieldToken(tokenAddress).MINTER_ROLE(), tokenIssuer);
        IAccessControl(accessManager).grantRole(SMARTYieldToken(tokenAddress).BURNER_ROLE(), tokenIssuer);
        IAccessControl(accessManager).grantRole(SMARTYieldToken(tokenAddress).FREEZER_ROLE(), tokenIssuer);
        IAccessControl(accessManager).grantRole(SMARTYieldToken(tokenAddress).FORCED_TRANSFER_ROLE(), tokenIssuer);
        IAccessControl(accessManager).grantRole(SMARTYieldToken(tokenAddress).RECOVERY_ROLE(), tokenIssuer);
        IAccessControl(accessManager).grantRole(SMARTYieldToken(tokenAddress).PAUSER_ROLE(), tokenIssuer);
        IAccessControl(accessManager).grantRole(SMARTSystemRoles.CLAIM_MANAGER_ROLE, tokenIssuer);
        vm.stopPrank();

        // 2. Create the token's on-chain identity
        tokenUtils.createAndSetTokenOnchainID(tokenAddress, tokenIssuer, address(accessManager));

        // 3. Set token in AbstractSMARTTest
        token = ISMART(tokenAddress);
    }
}
