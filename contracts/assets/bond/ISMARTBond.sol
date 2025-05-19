// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

// OpenZeppelin imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface imports
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";
import { ISMART } from "../../interface/ISMART.sol";

import { ISMARTTokenAccessManaged } from "../../extensions/access-managed/ISMARTTokenAccessManaged.sol";
import { ISMARTCustodian } from "../../extensions/custodian/ISMARTCustodian.sol";
import { ISMARTPausable } from "../../extensions/pausable/ISMARTPausable.sol";
import { ISMARTBurnable } from "../../extensions/burnable/ISMARTBurnable.sol";
import { ISMARTRedeemable } from "../../extensions/redeemable/ISMARTRedeemable.sol";
import { ISMARTHistoricalBalances } from "../../extensions/historical-balances/ISMARTHistoricalBalances.sol";
import { ISMARTYield } from "../../extensions/yield/ISMARTYield.sol";

interface ISMARTBond is
    ISMART,
    ISMARTTokenAccessManaged,
    ISMARTCustodian,
    ISMARTPausable,
    ISMARTBurnable,
    ISMARTRedeemable,
    ISMARTHistoricalBalances,
    ISMARTYield
{
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 cap_,
        uint256 maturityDate_,
        uint256 faceValue_,
        address underlyingAsset_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_,
        address identityRegistry_,
        address compliance_,
        address accessManager_
    )
        external;

    // --- View Functions ---

    /// @notice Returns the timestamp when the bond matures
    /// @return The maturity date timestamp
    function maturityDate() external view returns (uint256);

    /// @notice Returns the face value of the bond
    /// @return The bond's face value in underlying asset base units
    function faceValue() external view returns (uint256);

    /// @notice Returns the underlying asset contract
    /// @return The ERC20 contract of the underlying asset
    function underlyingAsset() external view returns (IERC20);
    /// @notice Returns the amount of underlying assets held by the contract
    /// @return The balance of underlying assets
    function underlyingAssetBalance() external view returns (uint256);

    /// @notice Returns the total amount of underlying assets needed for all potential redemptions
    /// @return The total amount of underlying assets needed
    function totalUnderlyingNeeded() external view returns (uint256);

    /// @notice Returns the amount of underlying assets missing for all potential redemptions
    /// @return The amount of underlying assets missing (0 if there's enough or excess)
    function missingUnderlyingAmount() external view returns (uint256);

    /// @notice Returns the amount of excess underlying assets that can be withdrawn
    /// @return The amount of excess underlying assets
    function withdrawableUnderlyingAmount() external view returns (uint256);

    // --- State-Changing Functions ---

    /// @notice Closes off the bond at maturity
    /// @dev Only callable by addresses with SUPPLY_MANAGEMENT_ROLE after maturity date
    /// @dev Requires sufficient underlying assets for all potential redemptions
    function mature() external;
}
