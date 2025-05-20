// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

// OpenZeppelin imports
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";

// Interface imports
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";
import { ISMART } from "../../interface/ISMART.sol";

import { ISMARTTokenAccessManaged } from "../../extensions/access-managed/ISMARTTokenAccessManaged.sol";
import { ISMARTCustodian } from "../../extensions/custodian/ISMARTCustodian.sol";
import { ISMARTPausable } from "../../extensions/pausable/ISMARTPausable.sol";
import { ISMARTBurnable } from "../../extensions/burnable/ISMARTBurnable.sol";
import { ISMARTCollateral } from "../../extensions/collateral/ISMARTCollateral.sol";

interface ISMARTFund is ISMART, ISMARTTokenAccessManaged, ISMARTCustodian, ISMARTPausable, ISMARTBurnable, IVotes {
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint16 managementFeeBps_,
        string memory fundClass_,
        string memory fundCategory_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_,
        address identityRegistry_,
        address compliance_,
        address accessManager_
    )
        external;
}
