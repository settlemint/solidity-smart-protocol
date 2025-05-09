// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
import { ISMARTIdentityRegistry } from "./../../../interface/ISMARTIdentityRegistry.sol";
import { IERC3643TrustedIssuersRegistry } from "./../../../interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IClaimIssuer } from "@onchainid/contracts/interface/IClaimIssuer.sol";
import { InsufficientCollateral, InvalidCollateralTopic } from "./../SMARTCollateralErrors.sol";
import { ISMARTCollateral } from "./../ISMARTCollateral.sol";
/// @title Internal Logic for SMART Collateral Extension
/// @notice Contains the core internal logic for verifying collateral claims before minting tokens.
/// @dev This abstract contract provides the `findValidCollateralClaim` helper and the `_collateral_beforeMintLogic`
///      hook implementation. It requires inheriting contracts to provide `totalSupply()` and `onchainID()`.

abstract contract _SMARTCollateralLogic is _SMARTExtension, ISMARTCollateral {
    // -- State Variables --

    /// @notice The ERC-735 claim topic ID representing the required collateral proof.
    uint256 private collateralProofTopic;

    // -- Internal Setup Function --

    /// @notice Initializes the collateral proof topic ID.
    /// @dev Stores the topic ID used to look up collateral claims. Reverts if the topic is 0.
    ///      This function should only be called once during the contract's initialization phase.
    /// @param collateralProofTopic_ The uint256 ID representing the collateral proof claim topic.
    function __SMARTCollateral_init_unchained(uint256 collateralProofTopic_) internal {
        if (collateralProofTopic_ == 0) {
            revert InvalidCollateralTopic(collateralProofTopic_);
        }
        collateralProofTopic = collateralProofTopic_;
        _registerInterface(type(ISMARTCollateral).interfaceId);
    }

    // -- Public View Helper Function --

    /// @inheritdoc ISMARTCollateral
    function findValidCollateralClaim()
        public
        view
        virtual
        override
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

        // Iterate through claims and find the first valid one
        for (uint256 j = 0; j < claimIds.length; j++) {
            (bool validClaim, uint256 claimAmount, address claimIssuer, uint256 claimExpiry) =
                _checkSingleClaim(tokenID, claimIds[j], trustedIssuers);

            if (validClaim) {
                return (claimAmount, claimIssuer, claimExpiry);
            }
        }

        // No valid claim found after checking all possibilities
        return (0, address(0), 0);
    }

    // -- Private Helper Functions --

    /// @dev Validates if a claim is valid via the trusted issuer and decodes its data.
    /// @param issuer The trusted issuer to check with.
    /// @param tokenIdentity The identity contract.
    /// @param claimTopic The topic of the claim.
    /// @param signature The signature of the claim.
    /// @param data The data of the claim.
    /// @return isValid True if claim is valid by the issuer.
    function _checkClaimValidity(
        IClaimIssuer issuer,
        IIdentity tokenIdentity,
        uint256 claimTopic,
        bytes memory signature,
        bytes memory data
    )
        private
        view
        returns (bool isValid)
    {
        try issuer.isClaimValid(tokenIdentity, claimTopic, signature, data) returns (bool valid) {
            return valid;
        } catch {
            return false;
        }
    }

    /// @dev Decodes claim data into amount and expiry timestamp.
    /// @param data The encoded claim data.
    /// @return decoded True if decoding was successful.
    /// @return amount The decoded amount (0 if decode failed).
    /// @return expiry The decoded expiry timestamp (0 if decode failed).
    function _decodeClaimData(bytes memory data) private view returns (bool decoded, uint256 amount, uint256 expiry) {
        if (data.length != 64) {
            return (false, 0, 0);
        }

        (amount, expiry) = abi.decode(data, (uint256, uint256));

        // Check if the claim has expired
        if (expiry <= block.timestamp) {
            return (false, 0, 0);
        }

        return (true, amount, expiry);
    }

    /// @dev Attempts to validate one claim against one issuer.
    /// @param issuer The trusted issuer.
    /// @param tokenIdentity The identity contract.
    /// @param topic The claim topic.
    /// @param signature The claim signature.
    /// @param data The claim data.
    /// @return success Whether validation succeeded.
    /// @return amount The collateral amount if successful.
    /// @return expiry The expiry timestamp if successful.
    function _tryClaimWithIssuer(
        IClaimIssuer issuer,
        IIdentity tokenIdentity,
        uint256 topic,
        bytes memory signature,
        bytes memory data
    )
        private
        view
        returns (bool success, uint256 amount, uint256 expiry)
    {
        bool isValid = _checkClaimValidity(issuer, tokenIdentity, topic, signature, data);

        if (!isValid) {
            return (false, 0, 0);
        }

        (bool decoded, uint256 decodedAmount, uint256 decodedExpiry) = _decodeClaimData(data);

        if (!decoded) {
            return (false, 0, 0);
        }

        return (true, decodedAmount, decodedExpiry);
    }

    /// @dev Checks a specific claimId for validity among trusted issuers.
    /// @param tokenID The identity token.
    /// @param claimId The ID of the claim to check.
    /// @param trustedIssuers Array of trusted claim issuers.
    /// @return validClaim Whether a valid claim was found.
    /// @return amount The claim amount if valid.
    /// @return issuer The issuer address if valid.
    /// @return expiry The expiry timestamp if valid.
    function _checkSingleClaim(
        IIdentity tokenID,
        bytes32 claimId,
        IClaimIssuer[] memory trustedIssuers
    )
        private
        view
        returns (bool validClaim, uint256 amount, address issuer, uint256 expiry)
    {
        // Try to get the claim details
        try tokenID.getClaim(claimId) returns (
            uint256 topic,
            uint256, // scheme unused
            address claimIssuer,
            bytes memory signature,
            bytes memory data,
            string memory // uri unused
        ) {
            // Only proceed if topic matches our collateral topic
            if (topic != collateralProofTopic) {
                return (false, 0, address(0), 0);
            }

            // Look for a matching trusted issuer
            for (uint256 i = 0; i < trustedIssuers.length; i++) {
                IClaimIssuer trustedIssuer = trustedIssuers[i];
                address trustedIssuerAddr = address(trustedIssuer);

                // Skip if this isn't the issuer of the claim
                if (claimIssuer != trustedIssuerAddr) {
                    continue;
                }

                // We found the matching issuer, try to validate the claim
                (bool success, uint256 claimAmount, uint256 claimExpiry) =
                    _tryClaimWithIssuer(trustedIssuer, tokenID, topic, signature, data);

                if (success) {
                    return (true, claimAmount, claimIssuer, claimExpiry);
                }

                // We found the right issuer but claim wasn't valid,
                // no need to check other issuers for this claim
                break;
            }
        } catch {
            // getClaim reverted, skip this claim
        }

        return (false, 0, address(0), 0);
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
