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

/// @title Interface for a SMART Fund
/// @notice Defines the core functionality and extensions for a SMART Fund, including voting capabilities.
interface ISMARTFund is ISMART, ISMARTTokenAccessManaged, ISMARTCustodian, ISMARTPausable, ISMARTBurnable, IVotes {
    /// @notice Initializes the SMART Fund contract.
    /// @param name_ The name of the fund.
    /// @param symbol_ The symbol of the fund.
    /// @param decimals_ The number of decimals for the fund tokens.
    /// @param managementFeeBps_ The management fee in basis points.
    /// @param fundClass_ The class of the fund (e.g., Equity, Fixed Income).
    /// @param fundCategory_ The category of the fund (e.g., Growth, Value).
    /// @param requiredClaimTopics_ An array of claim topics required for interacting with the fund.
    /// @param initialModulePairs_ An array of initial compliance module and parameter pairs.
    /// @param identityRegistry_ The address of the identity registry contract.
    /// @param compliance_ The address of the compliance contract.
    /// @param accessManager_ The address of the access manager contract for this token.
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

    /// @notice Returns the class of the fund.
    /// @return The fund class (e.g., "Equity", "Fixed Income").
    function fundClass() external view returns (string memory);

    /// @notice Returns the category of the fund.
    /// @return The fund category (e.g., "Growth", "Value").
    function fundCategory() external view returns (string memory);

    /// @notice Returns the management fee in basis points.
    /// @return The management fee in BPS.
    function managementFeeBps() external view returns (uint16);

    /// @notice Allows the fund manager to collect accrued management fees.
    /// @return The amount of fees collected.
    function collectManagementFee() external returns (uint256);
}
