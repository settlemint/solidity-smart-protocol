// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SMARTCoreTest } from "./tests/SMARTCoreTest.sol";
import { SMARTBurnableTest } from "./tests/SMARTBurnableTest.sol";
import { SMARTPausableTest } from "./tests/SMARTPausableTest.sol";
import { SMARTCustodianTest } from "./tests/SMARTCustodianTest.sol";
import { SMARTCollateralTest } from "./tests/SMARTCollateralTest.sol";
import { SMARTCountryAllowListTest } from "./tests/SMARTCountryAllowListTest.sol";
import { SMARTCountryBlockListTest } from "./tests/SMARTCountryBlockListTest.sol";
import { ISMART } from "../contracts/interface/ISMART.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SMARTTokenUpgradeable } from "../contracts/SMARTTokenUpgradeable.sol";
import { TestConstants } from "./Constants.sol";
// Contract for testing the UPGRADEABLE SMART token implementation

contract SMARTUpgradeableTest is
    SMARTCoreTest,
    SMARTBurnableTest,
    SMARTPausableTest,
    SMARTCustodianTest,
    SMARTCollateralTest,
    SMARTCountryAllowListTest,
    SMARTCountryBlockListTest
{
    function _setupToken() internal override {
        // 1. Deploy the implementation contract (no constructor args for upgradeable)
        vm.startPrank(tokenIssuer);
        SMARTTokenUpgradeable implementation = new SMARTTokenUpgradeable();

        // 2. Encode the initializer call data
        bytes memory initializeData = abi.encodeWithSelector(
            implementation.initialize.selector,
            "Test Bond",
            "TSTB",
            18, // Standard decimals
            address(0), // onchainID will be set by _createAndSetTokenOnchainID via proxy
            address(infrastructureUtils.identityRegistry()),
            address(infrastructureUtils.compliance()),
            requiredClaimTopics,
            modulePairs,
            TestConstants.CLAIM_TOPIC_COLLATERAL,
            tokenIssuer // Initial owner
        );

        // 3. Deploy the ERC1967Proxy pointing to the implementation and initializing it
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initializeData);
        address tokenProxyAddress = address(proxy);
        vm.stopPrank();

        // 4. Create the token's on-chain identity (using platform admin)
        tokenUtils.createAndSetTokenOnchainID(tokenProxyAddress, tokenIssuer);

        token = ISMART(tokenProxyAddress);
    }
}
