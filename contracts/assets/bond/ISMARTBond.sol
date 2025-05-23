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
import { ISMARTCapped } from "../../extensions/capped/ISMARTCapped.sol";

/// @title Interface for a SMART Bond
/// @notice Defines the core functionality and extensions for a SMART Bond, including features like redeemability,
/// historical balances, yield, and capping.
interface ISMARTBond is
    ISMART,
    ISMARTTokenAccessManaged,
    ISMARTCustodian,
    ISMARTPausable,
    ISMARTBurnable,
    ISMARTRedeemable,
    ISMARTHistoricalBalances,
    ISMARTCapped,
    ISMARTYield
{
    // --- Custom Errors ---
    /// @notice Error an action is attempted on a bond that has already matured.
    error BondAlreadyMatured();
    /// @notice Error an action is attempted that requires the bond to be matured, but it is not.
    error BondNotYetMatured();
    /// @notice Error an invalid maturity date was provided during initialization (e.g., in the past).
    error BondInvalidMaturityDate();
    /// @notice Error an invalid underlying asset address was provided (e.g., zero address).
    error InvalidUnderlyingAsset();
    /// @notice Error an invalid face value was provided (e.g., zero).
    error InvalidFaceValue();
    /// @notice Error the contract does not hold enough underlying asset balance for an operation.
    error InsufficientUnderlyingBalance();
    /// @notice Error an invalid redemption amount was specified.
    error InvalidRedemptionAmount();
    /// @notice Error the caller does not have enough redeemable bond tokens for the operation.
    error InsufficientRedeemableBalance();

    /// @notice Initializes the SMART Bond contract.
    /// @param name_ The name of the bond.
    /// @param symbol_ The symbol of the bond.
    /// @param decimals_ The number of decimals for the bond tokens.
    /// @param cap_ The maximum total supply of the bond tokens.
    /// @param maturityDate_ The Unix timestamp representing the bond's maturity date.
    /// @param faceValue_ The face value of each bond token in the underlying asset's base units.
    /// @param underlyingAsset_ The address of the ERC20 token used as the underlying asset for the bond.
    /// @param requiredClaimTopics_ An array of claim topics required for interacting with the bond.
    /// @param initialModulePairs_ An array of initial compliance module and parameter pairs.
    /// @param identityRegistry_ The address of the identity registry contract.
    /// @param compliance_ The address of the compliance contract.
    /// @param accessManager_ The address of the access manager contract for this token.
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

    /// @notice Returns true if the bond has matured (i.e., the current timestamp is past or at the maturity date).
    /// @return A boolean indicating if the bond has matured.
    function isMatured() external view returns (bool);

    /// @notice Returns the Unix timestamp when the bond matures.
    /// @return The maturity date timestamp.
    function maturityDate() external view returns (uint256);

    /// @notice Returns the face value of the bond per token.
    /// @return The bond's face value in the underlying asset's base units.
    function faceValue() external view returns (uint256);

    /// @notice Returns the ERC20 contract address of the underlying asset.
    /// @return The IERC20 contract instance of the underlying asset.
    function underlyingAsset() external view returns (IERC20);

    /// @notice Returns the amount of underlying assets currently held by this bond contract.
    /// @return The balance of underlying assets.
    function underlyingAssetBalance() external view returns (uint256);

    /// @notice Returns the total amount of underlying assets needed to cover all potential redemptions of outstanding
    /// bond tokens.
    /// @return The total amount of underlying assets needed.
    function totalUnderlyingNeeded() external view returns (uint256);

    /// @notice Returns the amount of underlying assets missing to cover all potential redemptions.
    /// @return The amount of underlying assets missing (0 if there's enough or an excess).
    function missingUnderlyingAmount() external view returns (uint256);

    /// @notice Returns the amount of excess underlying assets that can be withdrawn by the issuer after ensuring all
    /// redemptions can be met.
    /// @return The amount of excess underlying assets that are withdrawable.
    function withdrawableUnderlyingAmount() external view returns (uint256);

    // --- State-Changing Functions ---

    /// @notice Closes off the bond at maturity, performing necessary state changes.
    /// @dev Typically callable by addresses with a specific role (e.g., SUPPLY_MANAGEMENT_ROLE) only after the maturity
    /// date.
    /// @dev May require sufficient underlying assets to be present for all potential redemptions before execution.
    function mature() external;
}
