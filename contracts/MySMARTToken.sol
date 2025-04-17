// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SMARTToken } from "./SMART/SMARTToken.sol";
import { ISMART } from "./SMART/interface/ISMART.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MySMARTToken
/// @notice A complete implementation of a SMART token with all available extensions

contract MySMARTToken is SMARTToken {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        ISMART.ComplianceModuleParamPair[] memory initialModulePairs_,
        address initialOwner_
    )
        SMARTToken(
            name_,
            symbol_,
            decimals_,
            onchainID_,
            identityRegistry_,
            compliance_,
            requiredClaimTopics_,
            initialModulePairs_,
            initialOwner_
        )
    { }
}
