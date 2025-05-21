// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

// Interface imports
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";
import { ISMART } from "../../interface/ISMART.sol";

import { ISMARTTokenAccessManaged } from "../../extensions/access-managed/ISMARTTokenAccessManaged.sol";
import { ISMARTCustodian } from "../../extensions/custodian/ISMARTCustodian.sol";
import { ISMARTPausable } from "../../extensions/pausable/ISMARTPausable.sol";
import { ISMARTBurnable } from "../../extensions/burnable/ISMARTBurnable.sol";
import { ISMARTCollateral } from "../../extensions/collateral/ISMARTCollateral.sol";

interface ISMARTStableCoin is
    ISMART,
    ISMARTTokenAccessManaged,
    ISMARTCollateral,
    ISMARTCustodian,
    ISMARTPausable,
    ISMARTBurnable
{
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_,
        address identityRegistry_,
        address compliance_,
        address accessManager_
    )
        external;
}
