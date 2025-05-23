// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { ISMARTTokenFactory } from "../../system/token-factory/ISMARTTokenFactory.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

interface ISMARTEquityFactory is ISMARTTokenFactory {
    function createEquity(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        string memory equityClass_,
        string memory equityCategory_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        returns (address deployedEquityAddress);

    function predictEquityAddress(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        string memory equityClass_,
        string memory equityCategory_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        view
        returns (address predictedAddress);
}
