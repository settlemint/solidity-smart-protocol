// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTCollateral {
    /// @notice Finds the first valid collateral claim for a given identity address based on the configured topic.
    /// @dev Iterates through trusted issuers for the `collateralProofTopic`. For each potential claim found
    ///      on the user's identity contract (`onchainID`), it checks:
    ///      1. The claim's topic matches `collateralProofTopic`.
    ///      2. The claim's issuer is listed in the `identityRegistry`'s `issuersRegistry` as trusted for this topic.
    ///      3. The trusted issuer contract confirms the claim is currently valid (`isClaimValid`).
    ///      4. The claim data can be decoded into an amount and expiry timestamp.
    ///      5. The claim has not expired (`decodedExpiry > block.timestamp`).
    ///      Returns the details of the *first* claim that satisfies all conditions.
    /// @return amount The collateral amount decoded from the valid claim data (0 if no valid claim found).
    /// @return issuer The address of the trusted claim issuer contract that issued the valid claim (address(0) if
    /// none).
    /// @return expiryTimestamp The expiry timestamp decoded from the valid claim data (0 if no valid claim found).
    function findValidCollateralClaim()
        external
        view
        returns (uint256 amount, address issuer, uint256 expiryTimestamp);
}
