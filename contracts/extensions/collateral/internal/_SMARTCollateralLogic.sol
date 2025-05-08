// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

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
                            // Use the helper function to validate and decode this specific claim attempt.
                            (bool claimValidated, uint256 validatedAmount, uint256 validatedExpiry) =
                            _validateAndDecodeSingleClaimAttempt(
                                trustedIssuerInstance, // IClaimIssuer
                                tokenID, // IIdentity (cast from this.onchainID())
                                topic, // uint256 (retrieved from claim, already checked against collateralProofTopic)
                                signature, // bytes memory
                                data // bytes memory
                            );

                            if (claimValidated) {
                                // Found a valid, non-expired claim from a trusted issuer.
                                return (validatedAmount, claimIssuer, validatedExpiry);
                            }
                            // Optimization: If we found the matching trusted issuer for this claimId,
                            // and the claim attempt failed (e.g. revoked, expired, bad data),
                            // no need to check other trusted issuers for this specific claimId.
                            // We break to move to the next claimId or finish.
                            break;
                        }
                    }
                }
            } catch { /* getClaim reverted (e.g., claim removed), continue to the next claimId */ }
        }

        // No valid claim found after checking all possibilities.
        return (0, address(0), 0);
    }

    // -- Private Helper Functions

    /// @dev Validates a single claim attempt against a trusted issuer, decodes its data, and checks expiry.
    /// @param _trustedIssuer The specific trusted issuer instance to check against.
    /// @param _tokenIdentity The identity contract of the token holder.
    /// @param _claimTopic The topic of the claim (must match collateralProofTopic).
    /// @param _claimSignature The signature of the claim.
    /// @param _claimData The data of the claim.
    /// @return success True if the claim is valid, non-expired, and successfully decoded.
    /// @return amount The decoded collateral amount if successful, otherwise 0.
    /// @return expiryTimestamp The decoded expiry timestamp if successful, otherwise 0.
    function _validateAndDecodeSingleClaimAttempt(
        IClaimIssuer _trustedIssuer,
        IIdentity _tokenIdentity,
        uint256 _claimTopic,
        bytes memory _claimSignature,
        bytes memory _claimData
    )
        private
        view
        returns (bool success, uint256 amount, uint256 expiryTimestamp)
    {
        bool issuerSaysValid = false;
        try _trustedIssuer.isClaimValid(_tokenIdentity, _claimTopic, _claimSignature, _claimData) returns (bool isValid)
        {
            issuerSaysValid = isValid;
        } catch {
            // Treat revert/error from issuer call as an invalid claim for this attempt.
            return (false, 0, 0);
        }

        if (issuerSaysValid) {
            // Expect data to be abi.encode(uint256 amount, uint256 expiry).
            // Check data length to prevent abi.decode from reverting with incorrectly sized data.
            if (_claimData.length == 64) {
                (uint256 decodedAmount, uint256 decodedExpiry) = abi.decode(_claimData, (uint256, uint256));

                // Check if the claim has expired.
                if (decodedExpiry > block.timestamp) {
                    // Claim is valid, not expired, and data decoded successfully.
                    return (true, decodedAmount, decodedExpiry);
                }
            }
        }
        // If any check failed (not valid by issuer, wrong data length, or expired).
        return (false, 0, 0);
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
