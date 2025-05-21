// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { ISMARTTokenFactory } from "../../system/token-factory/ISMARTTokenFactory.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

interface ISMARTFundFactory is ISMARTTokenFactory {
    function createFund(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint16 managementFeeBps_,
        string memory fundClass_,
        string memory fundCategory_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        returns (address deployedFundAddress);
}
