// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISMARTHistoricalBalances } from "./../historical-balances/ISMARTHistoricalBalances.sol";

/// @title Interface for the SMART Yield Extension
/// @notice This interface defines the functions that a SMART Yield token extension must implement.
/// It allows for the management of a yield schedule associated with a token, which dictates how yield is accrued and
/// paid out.
/// This interface also inherits from `ISMARTHistoricalBalances`, indicating that any implementing contract
/// must also support querying token balances at historical points in time, a feature often crucial for accurate yield
/// calculations.
/// @dev This interface is intended to be implemented by contracts that provide yield-generating capabilities for
/// tokens.
/// The functions are external, allowing them to be called from other contracts or off-chain applications.
interface ISMARTYield is ISMARTHistoricalBalances {
    /// @notice Sets or updates the yield schedule contract for this token.
    /// @dev This function is crucial for configuring how yield is generated and distributed for the token.
    /// The `schedule` address points to another smart contract that implements the `ISMARTYieldSchedule` interface (or
    /// a more specific one like `ISMARTFixedYieldSchedule`).
    /// This schedule contract will contain the detailed logic for yield calculation, timing, and distribution.
    /// Implementers should consider adding access control to this function (e.g., only allowing an admin or owner role)
    /// to prevent unauthorized changes to the yield mechanism.
    /// @param schedule The address of the smart contract that defines the yield schedule. This contract must adhere to
    /// `ISMARTYieldSchedule`.
    function setYieldSchedule(address schedule) external;

    /// @notice Returns the address of the yield schedule contract for this token.
    /// @return schedule The address of the yield schedule contract.
    function yieldSchedule() external view returns (address schedule);

    /// @notice Returns the basis amount used to calculate yield per single unit of the token (e.g., per 1 token with 18
    /// decimals).
    /// @dev The "yield basis" is a fundamental value upon which yield calculations are performed. For example:
    /// - For a bond-like token, this might be its face value (e.g., 100 USD).
    /// - For an equity-like token, it might be its nominal value or a value derived from an oracle.
    /// This function allows the basis to be specific to a `holder`, enabling scenarios where different holders might
    /// have different
    /// yield bases (though often it will be a global value, in which case `holder` might be ignored).
    /// The returned value is typically a raw number (e.g., if basis is $100 and token has 2 decimals, this might return
    /// 10000).
    /// @param holder The address of the token holder for whom the yield basis is being queried. This allows for
    /// holder-specific configurations.
    /// @return basisPerUnit The amount (in the smallest unit of the basis currency/asset) per single unit of the token,
    /// used for yield calculations.
    function yieldBasisPerUnit(address holder) external view returns (uint256 basisPerUnit);

    /// @notice Returns the ERC20 token contract that is used for paying out the yield.
    /// @dev Yield can be paid in the token itself or in a different token (e.g., a stablecoin).
    /// This function specifies which ERC20 token will be transferred to holders when they claim their accrued yield.
    /// @return paymentToken An `IERC20` interface instance representing the token used for yield payments.
    function yieldToken() external view returns (IERC20 paymentToken);
}
