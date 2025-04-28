// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
import { ISMARTIdentityRegistry } from "./../../../interface/ISMARTIdentityRegistry.sol";
import { IERC3643TrustedIssuersRegistry } from "./../../../interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IClaimIssuer } from "@onchainid/contracts/interface/IClaimIssuer.sol";

/// @title Internal Logic for SMART Collateral Extension
/// @notice Contains the core internal logic for verifying collateral claims before minting tokens.
/// @dev This abstract contract provides the `findValidCollateralClaim` helper and the `_collateral_beforeMintLogic`
///      hook implementation. It requires inheriting contracts to provide `totalSupply()` and `onchainID()`.
abstract contract _SMARTCollateralLogic is _SMARTExtension {
    // -- State Variables --

    /// @notice The ERC-735 claim topic ID representing the required collateral proof.
    uint256 private collateralProofTopic;

    // -- Custom Errors --

    /// @notice Reverts if the required total supply (current + minted amount) exceeds the collateral amount found in a
    /// valid claim.
    /// @param required The total supply required after minting.
    /// @param available The collateral amount available according to the valid claim.
    error InsufficientCollateral(uint256 required, uint256 available);

    /// @notice Reverts if the provided collateral proof topic ID is invalid during initialization (e.g., 0).
    /// @param topicId The invalid topic ID provided.
    error InvalidCollateralTopic(uint256 topicId); // Setup error

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
        // Ensure the collateral topic has been initialized
        if (collateralProofTopic == 0) {
            revert InvalidCollateralTopic(0);
        }

        // Retrieve necessary registry and identity contracts
        ISMARTIdentityRegistry identityRegistry_ = this.identityRegistry();
        IERC3643TrustedIssuersRegistry issuersRegistry = identityRegistry_.issuersRegistry();
        // Should we make onChainID public?
        IIdentity tokenID = IIdentity(this.onchainID()); // Get the specific user's identity contract

        // Get issuers trusted for the specific collateral proof topic
        IClaimIssuer[] memory trustedIssuers = issuersRegistry.getTrustedIssuersForClaimTopic(collateralProofTopic);

        // If no issuers are trusted for this topic, no valid claim can exist
        if (trustedIssuers.length == 0) {
            return (0, address(0), 0);
        }

        // Calculate the claim ID based on the user's address and the topic
        bytes32 claimId = keccak256(abi.encodePacked(tokenID, collateralProofTopic));

        // Attempt to retrieve the claim from the user's identity contract
        try tokenID.getClaim(claimId) returns (
            uint256 topic,
            uint256, // scheme unused
            address claimIssuer,
            bytes memory signature,
            bytes memory data,
            string memory // uri unused
        ) {
            // Verify the retrieved claim's topic matches the expected collateral topic
            if (topic == collateralProofTopic) {
                // Iterate through the list of trusted issuers for this topic
                for (uint256 i = 0; i < trustedIssuers.length; i++) {
                    IClaimIssuer trustedIssuerInstance = trustedIssuers[i];
                    address trustedIssuerAddress = address(trustedIssuerInstance);

                    // Check 1: Is the issuer of *this specific claim* in our trusted list for this topic?
                    if (claimIssuer == trustedIssuerAddress) {
                        // Check 2: Ask the trusted issuer contract if the claim signature/data is still valid (accounts
                        // for revocation)
                        bool issuerSaysValid = false;
                        try trustedIssuerInstance.isClaimValid(tokenID, topic, signature, data) returns (bool isValid) {
                            issuerSaysValid = isValid;
                        } catch { /* Treat revert/error from issuer as invalid */ }

                        if (issuerSaysValid) {
                            // Check 3: Decode amount and expiry from claim data
                            if (data.length > 0) {
                                (uint256 decodedAmount, uint256 decodedExpiry) = abi.decode(data, (uint256, uint256));

                                // Check 3a: Check if the claim has expired
                                if (decodedExpiry > block.timestamp) {
                                    // Success! Found a valid, non-expired claim from a trusted issuer.
                                    return (decodedAmount, claimIssuer, decodedExpiry);
                                } // else: Claim is expired, continue checking other trusted issuers
                            } // else: Claim data is empty, invalid format, continue checking
                        } // else: Issuer deems the claim invalid, continue checking
                    } // else: The issuer of this claim is not in the trusted list for this topic, continue checking
                } // End of loop through trusted issuers
            } // else: Topic mismatch, this is not the collateral claim we are looking for.
        } catch { /* getClaim reverted (e.g., claim doesn't exist), treat as no valid claim found */ }

        // If the loop completes or getClaim fails, no suitable claim was found.
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
