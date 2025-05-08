// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
import { ISMARTIdentityRegistry } from "./../../../interface/ISMARTIdentityRegistry.sol";
import { IERC3643TrustedIssuersRegistry } from "./../../../interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IClaimIssuer } from "@onchainid/contracts/interface/IClaimIssuer.sol";
import { InsufficientCollateral, InvalidCollateralTopic } from "./../SMARTCollateralErrors.sol";
/// @title Internal Logic for SMART Collateral Extension
/// @notice Contains the core internal logic for verifying collateral claims before minting tokens.
/// @dev This abstract contract provides the `findValidCollateralClaim` helper and the `_collateral_beforeMintLogic`
///      hook implementation. It requires inheriting contracts to provide `totalSupply()` and `onchainID()`.

abstract contract _SMARTCollateralLogic is _SMARTExtension {
    // -- State Variables --

    /// @notice The ERC-735 claim topic ID representing the required collateral proof.
    uint256 private collateralProofTopic;

    // -- Internal Setup Function --

    /// @notice Initializes the collateral proof topic ID.
    /// @dev Stores the topic ID used to look up collateral claims. Reverts if the topic is 0.
    ///      This function should only be called once during the contract's initialization phase.
    /// @param collateralProofTopic_ The uint256 ID representing the collateral proof claim topic.
    function _SMARTCollateral_init(uint256 collateralProofTopic_) internal {
        if (collateralProofTopic_ == 0) {
            revert InvalidCollateralTopic(collateralProofTopic_);
        }
        collateralProofTopic = collateralProofTopic_;
    }

    // -- Public View Helper Function --

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
        public
        view
        virtual
        returns (uint256 amount, address issuer, uint256 expiryTimestamp)
    {
        if (collateralProofTopic == 0) {
            revert InvalidCollateralTopic(0);
        }

        ISMARTIdentityRegistry identityRegistry_ = this.identityRegistry();
        IERC3643TrustedIssuersRegistry issuersRegistry = identityRegistry_.issuersRegistry();
        IIdentity tokenID = IIdentity(this.onchainID());

        IClaimIssuer[] memory trustedIssuers = issuersRegistry.getTrustedIssuersForClaimTopic(collateralProofTopic);

        if (trustedIssuers.length == 0) {
            return (0, address(0), 0);
        }

        bytes32[] memory claimIds = tokenID.getClaimIdsByTopic(collateralProofTopic);

        for (uint256 j = 0; j < claimIds.length; j++) {
            bytes32 currentClaimId = claimIds[j];

            // Attempt to retrieve the full claim details from the identity contract.
            try tokenID.getClaim(currentClaimId) returns (
                uint256 topic,
                uint256, // scheme unused
                address claimIssuer,
                bytes memory signature,
                bytes memory data,
                string memory // uri unused
            ) {
                // Ensure the retrieved claim is for the correct topic.
                if (topic == collateralProofTopic) {
                    // Check if the claim's issuer is in our list of trusted issuers for this topic.
                    for (uint256 i = 0; i < trustedIssuers.length; i++) {
                        IClaimIssuer trustedIssuerInstance = trustedIssuers[i];
                        address trustedIssuerAddress = address(trustedIssuerInstance);

                        if (claimIssuer == trustedIssuerAddress) {
                            // Ask the trusted issuer contract if the claim is still valid (accounts for revocation).
                            bool issuerSaysValid = false;
                            try trustedIssuerInstance.isClaimValid(tokenID, topic, signature, data) returns (
                                bool isValid
                            ) {
                                issuerSaysValid = isValid;
                            } catch { /* Treat revert/error from issuer call as invalid claim */ }

                            if (issuerSaysValid) {
                                // Expect data to be abi.encode(uint256 amount, uint256 expiry).
                                if (data.length == 64) {
                                    (uint256 decodedAmount, uint256 decodedExpiry) =
                                        abi.decode(data, (uint256, uint256));

                                    // Check if the claim has expired.
                                    if (decodedExpiry > block.timestamp) {
                                        // Found a valid, non-expired claim from a trusted issuer.
                                        return (decodedAmount, claimIssuer, decodedExpiry);
                                    }
                                }
                            }
                            // Optimization: If we found the matching trusted issuer for this claimId, no need to check
                            // others.
                            break;
                        }
                    }
                }
            } catch { /* getClaim reverted (e.g., claim removed), continue to the next claimId */ }
        }

        // No valid claim found after checking all possibilities.
        return (0, address(0), 0);
    }

    // -- Internal Hook Helper Function --

    /// @notice Internal logic executed by the `_beforeMint` hook to enforce collateral requirements.
    /// @dev This function is called within the `_beforeMint` hook implementation.
    ///      It uses `findValidCollateralClaim` to get the collateral amount associated with the recipient (`to`).
    ///      It then compares this amount against the projected total supply (`totalSupply() + amount`).
    ///      Reverts with `InsufficientCollateral` if the available collateral is less than the required total supply.
    /// @param amount The amount of tokens being minted.
    function _collateral_beforeMintLogic(uint256 amount) internal view virtual {
        // Find the valid collateral amount for the recipient using the public helper.
        // We only need the amount here, issuer and expiry are validated within the helper.
        (uint256 collateralAmountFromClaim,,) = findValidCollateralClaim();

        // TODO is it correct to use this.totalSupply()? or should we make this Abstract?
        // We need to use this. because totalSupply() is an external function and not virtual or public
        uint256 currentTotalSupply = this.totalSupply();
        uint256 requiredTotalSupply = currentTotalSupply + amount; // Calculate required supply *after* minting

        // Check if the collateral amount from the claim is sufficient to cover the new total supply.
        // If no valid claim was found, `collateralAmountFromClaim` will be 0, causing a revert unless
        // requiredTotalSupply is also 0.
        if (collateralAmountFromClaim < requiredTotalSupply) {
            revert InsufficientCollateral(requiredTotalSupply, collateralAmountFromClaim);
        }
    }

    // -- Abstract Dependencies -- Must be implemented by the inheriting contract
}
